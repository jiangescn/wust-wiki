package com.wustacm.wiki;

import android.app.Activity;
import android.content.*;
import android.content.pm.ApplicationInfo;
import android.graphics.*;
import android.graphics.pdf.PdfRenderer;
import android.os.*;
import android.security.keystore.*;
import android.util.Base64;
import com.google.android.gms.tasks.Tasks;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.*;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;
import org.json.*;
import javax.crypto.*;
import javax.crypto.spec.*;
import java.io.*;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.charset.*;
import java.security.*;
import java.security.spec.RSAPublicKeySpec;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/** Android system adapters derived from the AGPL-3.0 WUSTFoundation port. */
final class NativeCapabilities implements AutoCloseable {
    private static final AtomicInteger FILE_REQUEST_CODE = new AtomicInteger(0x5700);
    private static final int MAX_FILE_BYTES = 20 * 1024 * 1024;
    private final Activity activity;
    private final Context context;
    private final SharedPreferences preferences;
    private final SecretKey storageKey;
    private final ExecutorService workers = Executors.newFixedThreadPool(2);
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Set<Request> pending = ConcurrentHashMap.newKeySet();
    private volatile boolean closed;
    // Accessed on the main thread; held through the picker/write or PDF viewer lifetime.
    private FileOperation fileOperation;
    interface Callback { void complete(JSONObject value); void failed(String code); }
    NativeCapabilities(Activity activity) throws Exception {
        this.activity=activity;
        this.context=activity.getApplicationContext();
        preferences=context.getSharedPreferences("credentials",Context.MODE_PRIVATE);
        KeyStore store=KeyStore.getInstance("AndroidKeyStore"); store.load(null);
        String alias="WUSTFoundation.credentials";
        if(!store.containsAlias(alias)) {
            KeyGenerator generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
            generator.generateKey();
        }
        storageKey=(SecretKey)store.getKey(alias,null);
    }
    private final class Request implements Callback {
        private final Callback callback;
        private final AtomicBoolean finished = new AtomicBoolean();
        Request(Callback callback) { this.callback=callback; }
        public void complete(JSONObject value) { finish(value,null); }
        public void failed(String code) { finish(null,code); }
        private void finish(JSONObject value,String code) {
            if(!finished.compareAndSet(false,true)) return;
            pending.remove(this);
            main.post(()->{ if(code==null) callback.complete(value); else callback.failed(code); });
        }
    }
    private static final class FileOperation {
        final Request request;
        final boolean pdf;
        final int requestCode=FILE_REQUEST_CODE.getAndUpdate(value->value==0x7fff?0x5700:value+1);
        byte[] data;
        FileOperation(Request request,boolean pdf) { this.request=request; this.pdf=pdf; }
    }
    boolean hasSavedAccount() throws Exception {
        String account=load("active-account");
        if(account==null || account.isEmpty()) return false;
        for(String prefix:new String[]{"password:","session:","dart-session:","tgt:","union-session:","auth-blocked:","business-session:library:","business-session:shuttle:","business-session:second-class:"}) if(preferences.contains(prefix+account)) return true;
        return false;
    }
    private static byte[] bytes(JSONObject args,String name) throws Exception { return Base64.decode(args.getString(name),Base64.DEFAULT); }
    private static String encoded(byte[] value) { return Base64.encodeToString(value,Base64.NO_WRAP); }
    private String encrypt(String value) throws Exception {
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE,storageKey);
        return encoded(cipher.getIV())+"."+encoded(cipher.doFinal(value.getBytes(StandardCharsets.UTF_8)));
    }
    private String load(String key) throws Exception {
        String value=preferences.getString(key,null); if(value==null) return null;
        String[] parts=value.split("\\."); if(parts.length!=2) throw new IOException();
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE,storageKey,new GCMParameterSpec(128,Base64.decode(parts[0],Base64.DEFAULT)));
        return new String(cipher.doFinal(Base64.decode(parts[1],Base64.DEFAULT)),StandardCharsets.UTF_8);
    }
    void request(String operation,JSONObject args,Callback callback) {
        Request request=new Request(callback);
        synchronized(this) {
            if(closed) { request.failed("cancelled"); return; }
            pending.add(request);
        }
        if("exportFile".equals(operation) || "openPdf".equals(operation)) {
            main.post(()->startFile(operation,args,request));
        } else execute(request,()->request.complete(perform(operation,args)));
    }
    private interface Work { void run() throws Exception; }
    private void execute(Request request,Work work) {
        try {
            workers.execute(()->{
                if(closed) { request.failed("cancelled"); return; }
                try { work.run(); }
                catch(Exception error) { request.failed(error instanceof CancellationException || error instanceof InterruptedException ? "cancelled" : error instanceof IllegalArgumentException || error instanceof JSONException ? "invalid_arguments" : "platform_failed"); }
            });
        } catch(RejectedExecutionException error) { request.failed("cancelled"); }
    }
    private static String fileName(JSONObject args,boolean pdf) throws JSONException {
        String name=pdf?args.optString("name","notice.pdf"):args.getString("name");
        if(name.trim().isEmpty() || name.length()>128 || name.equals(".") || name.equals("..")) throw new IllegalArgumentException();
        for(int i=0;i<name.length();i++) if(Character.isISOControl(name.charAt(i)) || name.charAt(i)=='/' || name.charAt(i)=='\\') throw new IllegalArgumentException();
        return name;
    }
    private static String mimeType(JSONObject args) throws JSONException {
        return args.getString("mime").split(";",2)[0].trim();
    }
    private static byte[] fileBytes(JSONObject args) throws JSONException {
        String value=args.getString("base64");
        if(value.isEmpty() || value.length()>4*((MAX_FILE_BYTES+2)/3) || value.length()%4==1) throw new IllegalArgumentException();
        int padding=0;
        for(int i=0;i<value.length();i++) {
            char c=value.charAt(i);
            if(c=='=') { if(++padding>2 || i<value.length()-2) throw new IllegalArgumentException(); }
            else if(padding!=0 || !(c>='A'&&c<='Z' || c>='a'&&c<='z' || c>='0'&&c<='9' || c=='+' || c=='/')) throw new IllegalArgumentException();
        }
        byte[] data=Base64.decode(value,Base64.NO_WRAP);
        if(data.length==0 || data.length>MAX_FILE_BYTES) throw new IllegalArgumentException();
        return data;
    }
    private void startFile(String operation,JSONObject args,Request request) {
        if(closed || activity.isFinishing() || activity.isDestroyed()) { request.failed("cancelled"); return; }
        if(fileOperation!=null) { request.failed("busy"); return; }
        FileOperation file=new FileOperation(request,"openPdf".equals(operation)); fileOperation=file;
        execute(request,()->{
            try {
                String name=fileName(args,file.pdf);
                String mime=file.pdf?"application/pdf":args.getString("mime");
                mime=mime.split(";",2)[0].trim();
                if(mime.length()>127 || !mime.matches("[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+")) throw new IllegalArgumentException();
                byte[] data=fileBytes(args);
                if(file.pdf) {
                    File temp=File.createTempFile("notice-",".pdf",context.getCacheDir());
                    try {
                        try(OutputStream output=new FileOutputStream(temp)) { output.write(data); }
                        ParcelFileDescriptor descriptor=ParcelFileDescriptor.open(temp,ParcelFileDescriptor.MODE_READ_ONLY);
                        try {
                            PdfRenderer renderer=new PdfRenderer(descriptor); descriptor=null;
                            try(renderer) { if(renderer.getPageCount()<1) throw new IOException(); }
                        } finally { if(descriptor!=null) descriptor.close(); }
                        if(closed || Thread.currentThread().isInterrupted()) throw new CancellationException();
                        // Replace atomically so an existing renderer keeps its original descriptor.
                        if(!temp.renameTo(new File(context.getCacheDir(),"notice.pdf"))) throw new IOException();
                    } finally { temp.delete(); }
                }
                main.post(()->{
                    if(closed || fileOperation!=file || activity.isFinishing() || activity.isDestroyed()) { finishFile(file,"cancelled"); return; }
                    try {
                        if(file.pdf) {
                            Intent intent=new Intent(activity,PdfActivity.class).putExtra("name",name);
                            activity.startActivityForResult(intent,file.requestCode);
                            request.complete(new JSONObject().put("ok",true));
                        } else {
                            file.data=data;
                            Intent intent=new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                                .setType(mimeType(args)).putExtra(Intent.EXTRA_TITLE,name);
                            activity.startActivityForResult(intent,file.requestCode);
                        }
                    } catch(Exception error) { finishFile(file,"platform_failed"); }
                });
            } catch(Exception error) {
                main.post(()->finishFile(file,error instanceof CancellationException?"cancelled":error instanceof IllegalArgumentException || error instanceof JSONException?"invalid_arguments":"platform_failed"));
            }
        });
    }
    boolean onActivityResult(int requestCode,int resultCode,Intent data) {
        FileOperation file=fileOperation;
        if(file==null || file.requestCode!=requestCode) return false;
        if(file.pdf) { finishFile(file,null); return true; }
        if(resultCode!=Activity.RESULT_OK) {
            try { file.request.complete(new JSONObject().put("ok",false).put("cancelled",true)); }
            catch(JSONException error) { file.request.failed("platform_failed"); }
            finishFile(file,null); return true;
        }
        if(data==null || data.getData()==null) { finishFile(file,"invalid_response"); return true; }
        android.net.Uri uri=data.getData();
        if(!"content".equals(uri.getScheme())) { finishFile(file,"invalid_response"); return true; }
        byte[] content=file.data;
        // A duplicate activity result cannot start a second write.
        if(content==null) return true;
        file.data=null;
        execute(file.request,()->{
            try {
                try(OutputStream output=context.getContentResolver().openOutputStream(uri,"wt")) {
                    if(output==null) throw new IOException();
                    for(int offset=0;offset<content.length;offset+=8192) {
                        if(closed || Thread.currentThread().isInterrupted()) throw new CancellationException();
                        output.write(content,offset,Math.min(8192,content.length-offset));
                    }
                    output.flush();
                }
                main.post(()->{
                    if(closed) finishFile(file,"cancelled");
                    else {
                        try { file.request.complete(new JSONObject().put("ok",true)); }
                        catch(JSONException error) { file.request.failed("platform_failed"); }
                        finishFile(file,null);
                    }
                });
            } catch(Exception error) { main.post(()->finishFile(file,error instanceof CancellationException?"cancelled":"platform_failed")); }
        });
        return true;
    }
    private void finishFile(FileOperation file,String error) {
        if(fileOperation==file) fileOperation=null;
        file.data=null;
        if(error!=null) file.request.failed(error);
    }
    private JSONObject perform(String operation,JSONObject args) throws Exception {
        switch(operation) {
            case "load": { String value=load(args.getString("key")); return value==null?new JSONObject():new JSONObject().put("value",value); }
            case "save": {
                if(!preferences.edit().putString(args.getString("key"),encrypt(args.getString("value"))).commit()) throw new IOException();
                return new JSONObject();
            }
            case "clear": {
                if(!preferences.edit().remove(args.getString("key")).commit()) throw new IOException();
                return new JSONObject();
            }
            case "saveAccount": {
                String account=args.getString("username");
                if(!preferences.edit().putString("password:"+account,encrypt(args.getString("password")))
                    .putString("active-account",encrypt(account)).commit()) throw new IOException();
                return new JSONObject();
            }
            case "clearAccount": {
                String account=args.getString("username"); SharedPreferences.Editor edit=preferences.edit();
                for(String prefix:new String[]{"password:","session:","dart-session:","tgt:","union-session:","auth-blocked:","business-session:library:","business-session:shuttle:","business-session:second-class:"}) edit.remove(prefix+account);
                if(account.equals(load("active-account"))) edit.remove("active-account");
                if(!edit.commit()) throw new IOException(); return new JSONObject();
            }
            case "deviceID": {
                synchronized(preferences) {
                    String id=preferences.getString("deviceID",null);
                    if(id==null) { id=(UUID.randomUUID().toString()+UUID.randomUUID()).replace("-",""); if(!preferences.edit().putString("deviceID",id).commit()) throw new IOException(); }
                    return new JSONObject().put("value",id);
                }
            }
            case "digest": return new JSONObject().put("data",encoded(MessageDigest.getInstance(args.getString("algorithm")).digest(bytes(args,"data"))));
            case "aes": {
                Cipher cipher=Cipher.getInstance("AES/CBC/PKCS5Padding");
                cipher.init(Cipher.ENCRYPT_MODE,new SecretKeySpec(bytes(args,"key"),"AES"),new IvParameterSpec(bytes(args,"iv")));
                return new JSONObject().put("data",encoded(cipher.doFinal(bytes(args,"data"))));
            }
            case "rsa": {
                byte[] der=bytes(args,"key"), plain=bytes(args,"data");
                if(der.length<135 || plain.length>128) throw new IllegalArgumentException();
                RSAPublicKeySpec key=new RSAPublicKeySpec(new BigInteger(1,Arrays.copyOfRange(der,7,135)),BigInteger.valueOf(65537));
                Cipher cipher=Cipher.getInstance("RSA/ECB/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE,KeyFactory.getInstance("RSA").generatePublic(key));
                byte[] padded=new byte[128]; System.arraycopy(plain,0,padded,128-plain.length,plain.length);
                return new JSONObject().put("data",encoded(cipher.doFinal(padded)));
            }
            case "raster": return raster(args);
            case "ocr": {
                byte[] data=bytes(args,"data"); Bitmap bitmap=BitmapFactory.decodeByteArray(data,0,data.length);
                if(bitmap==null) throw new IOException();
                try(TextRecognizer recognizer=TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)) {
                    Text text=Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap,0)),30,TimeUnit.SECONDS);
                    return new JSONObject().put("text",text.getText().replace("\n",""));
                } finally { bitmap.recycle(); }
            }
            case "decodeText": {
                String charset=args.getString("charset").toUpperCase(Locale.ROOT);
                if(!Arrays.asList("GB18030","GBK","GB2312").contains(charset)) throw new IllegalArgumentException();
                String text=Charset.forName(charset).newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes(args,"data"))).toString();
                return new JSONObject().put("text",text);
            }
            case "acceptanceStatus": {
                if((context.getApplicationInfo().flags&ApplicationInfo.FLAG_DEBUGGABLE)==0) throw new SecurityException();
                try(OutputStream output=new FileOutputStream(new File(context.getFilesDir(),"dart-acceptance.json"))) {
                    output.write(args.toString().getBytes(StandardCharsets.UTF_8));
                }
                return new JSONObject();
            }
            default: throw new IllegalArgumentException();
        }
    }
    private JSONObject raster(JSONObject args) throws Exception {
        byte[] data=bytes(args,"data"); BitmapFactory.Options bounds=new BitmapFactory.Options(); bounds.inJustDecodeBounds=true;
        BitmapFactory.decodeByteArray(data,0,data.length,bounds);
        int width=bounds.outWidth,height=bounds.outHeight,requested=args.optInt("height",0);
        if(width<8 || width>2048 || height<8 || height>2048 || (requested!=0 && (requested<8 || requested>2048))) throw new IOException();
        Bitmap image=BitmapFactory.decodeByteArray(data,0,data.length); if(image==null) throw new IOException();
        if(requested!=0 && requested!=height) { Bitmap scaled=Bitmap.createScaledBitmap(image,width,requested,true); image.recycle(); image=scaled; height=requested; }
        try {
            int[] colors=new int[width*height]; image.getPixels(colors,0,width,0,0,width,height);
            byte[] pixels=new byte[colors.length*4];
            for(int i=0;i<colors.length;i++) { int color=colors[i],alpha=Color.alpha(color); pixels[4*i]=(byte)(Color.red(color)*alpha/255);
                pixels[4*i+1]=(byte)(Color.green(color)*alpha/255); pixels[4*i+2]=(byte)(Color.blue(color)*alpha/255); pixels[4*i+3]=(byte)alpha; }
            return new JSONObject().put("width",width).put("height",height).put("pixels",encoded(pixels));
        } finally { image.recycle(); }
    }
    @Override public synchronized void close() {
        closed=true;
        for(Request request:pending) request.failed("cancelled");
        if(fileOperation!=null) { fileOperation.data=null; fileOperation=null; }
        workers.shutdownNow();
    }
}
