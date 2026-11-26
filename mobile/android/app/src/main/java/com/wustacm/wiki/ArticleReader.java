package com.wustacm.wiki;

import android.content.Context;
import android.net.Uri;
import android.os.SystemClock;
import android.view.View;
import android.webkit.*;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.zip.*;

final class ArticleReader implements PlatformView {
    private static final String HOST="appassets.androidplatform.net";
    private static Future<ZipFile> resources;
    private final WebView web;
    private final MethodChannel channel;
    private boolean disposed;
    private volatile boolean readerDark;
    private boolean disableMotion, preparing, failed;
    private int navigation;

    private int background() {
        return readerDark ? 0xff1b1b1f : 0xfffafafa;
    }

    private void fail() {
        if (disposed || failed) return;
        failed = true;
        channel.invokeMethod("error", null);
    }

    private void prepareFirstFrame() {
        if (disposed || failed || preparing) return;
        preparing = true;
        prepareFirstFrame(navigation, SystemClock.uptimeMillis() + 850);
    }

    private void prepareFirstFrame(int page, long deadline) {
        if (disposed || failed || page != navigation) return;
        boolean allowBeforeHydration = SystemClock.uptimeMillis() >= deadline;
        String js = "window.wikiReaderPrepare?.(" + disableMotion + "," + allowBeforeHydration + ") === true";
        web.evaluateJavascript(js, result -> {
            if (disposed || failed || page != navigation) return;
            if (!"true".equals(result) && !allowBeforeHydration) {
                web.postDelayed(() -> prepareFirstFrame(page, deadline), 32);
                return;
            }
            web.postVisualStateCallback(page, new WebView.VisualStateCallback() {
                @Override public void onComplete(long id) {
                    if (!disposed && !failed && id == navigation) {
                        channel.invokeMethod("ready", null);
                    }
                }
            });
        });
    }

    // Seed Nuxt's own color-mode preference before its bootstrap script reads it.
    private InputStream themedHtml(InputStream html) throws IOException {
        byte[] marker = "<head>".getBytes(java.nio.charset.StandardCharsets.US_ASCII);
        ByteArrayOutputStream prefix = new ByteArrayOutputStream();
        int matched = 0;
        while (prefix.size() < 4096) {
            int b = html.read();
            if (b == -1) break;
            prefix.write(b);
            matched = b == marker[matched] ? matched + 1 : (b == marker[0] ? 1 : 0);
            if (matched == marker.length) {
                String mode = readerDark ? "dark" : "light";
                String script = "<script>localStorage.setItem('nuxt-color-mode','" + mode + "')</script>";
                prefix.write(script.getBytes(java.nio.charset.StandardCharsets.US_ASCII));
                break;
            }
        }
        return new SequenceInputStream(new ByteArrayInputStream(prefix.toByteArray()), html);
    }


    static synchronized Future<ZipFile> resources(Context ctx){
        if(resources==null){
            Context app=ctx.getApplicationContext();
            FutureTask<ZipFile> task=new FutureTask<>(()->{
                long updated=app.getPackageManager().getPackageInfo(app.getPackageName(),0).lastUpdateTime;
                File dir=new File(app.getCacheDir(),"reader-"+updated);
                if(!dir.isDirectory()&&!dir.mkdirs())throw new IOException("reader cache");
                File zip=new File(dir,"articles.zip");
                if(!zip.exists()){
                    File tmp=new File(dir,"bundle.partial");
                    try(InputStream src=app.getAssets().open("wiki-reader.zip");OutputStream dst=new FileOutputStream(tmp)){
                        byte[] bytes=new byte[65536];int n;
                        while((n=src.read(bytes))!=-1)dst.write(bytes,0,n);
                    }
                    if(!tmp.renameTo(zip))throw new IOException("reader cache");
                }
                return new ZipFile(zip);
            });
            resources=task;
            new Thread(task,"wiki-article-assets").start();
        }
        return resources;
    }
    private static String mime(String name){
        if(name.endsWith(".js")||name.endsWith(".mjs"))return "text/javascript";
        if(name.endsWith(".wasm"))return "application/wasm";
        if(name.endsWith(".svg"))return "image/svg+xml";
        if(name.endsWith(".css"))return "text/css";
        if(name.endsWith(".json"))return "application/json";
        if(name.endsWith(".html"))return "text/html";
        if(name.endsWith(".woff2"))return "font/woff2";
        String ext=MimeTypeMap.getFileExtensionFromUrl(name);
        String type=MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext);
        return type==null?"application/octet-stream":type;
    }
    private static WebResourceResponse missing(){return new WebResourceResponse("text/plain","UTF-8",404,"Not found",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}
    ArticleReader(Context context,MethodChannel channel,String path,boolean dark){
        this.channel=channel;readerDark=dark;web=new WebView(context);
        web.setBackgroundColor(background());
        WebSettings s=web.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(true);
        s.setAllowFileAccess(false);s.setAllowContentAccess(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        Future<ZipFile> files=resources(context);
        web.setWebChromeClient(new WebChromeClient());
        web.setWebViewClient(new WebViewClient(){
            @Override public WebResourceResponse shouldInterceptRequest(WebView v,WebResourceRequest req){
                Uri u=req.getUrl();if(!HOST.equals(u.getHost()))return req.isForMainFrame()?missing():null;
                String key=u.getPath();if(key==null||key.contains("..")||!key.startsWith("/"))return missing();
                key=key.substring(1);
                try{
                    ZipFile zip=files.get();
                    ZipEntry e=zip.getEntry(key);
                    if(e==null || e.isDirectory())e=zip.getEntry(key.replaceAll("/$","")+"/index.html");
                    if(e==null)return missing();
                    String type=mime(e.getName());Map<String,String> headers=new HashMap<>();
                    if(type.equals("text/html"))headers.put("Content-Security-Policy","default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; font-src 'self' data: https:; media-src 'self' blob: data: https:; frame-src https://player.bilibili.com https://www.bilibili.com https://www.youtube.com https://open.douyin.com https://www.tiktok.com; connect-src 'self' https:; worker-src 'self' blob:; object-src 'none'; base-uri 'self'");
                    InputStream content=zip.getInputStream(e);
                    return new WebResourceResponse(type,type.startsWith("text/")?"UTF-8":null,200,"OK",headers,type.equals("text/html")?themedHtml(content):content);
                }catch(Exception error){return missing();}
            }
            @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest req){
                if(!req.isForMainFrame())return false;
                Uri u=req.getUrl();
                if("wikireader".equals(u.getScheme()) && "open".equals(u.getHost())) {
                    String target=u.getQueryParameter("url");if(target!=null)forward(Uri.parse(target));
                }else if("https".equals(u.getScheme())||"http".equals(u.getScheme())){
                    if(HOST.equals(u.getHost())&&path.equals(u.getPath())&&u.getFragment()!=null)return false;
                    forward(u);
                }
                return true;
            }
            private void forward(Uri u){
                if(disposed||!("https".equals(u.getScheme())||"http".equals(u.getScheme())))return;
                if(HOST.equals(u.getHost()))u=u.buildUpon().authority("wiki.wustacm.com").build();
                channel.invokeMethod("open",u.toString());
            }
            @Override public void onReceivedHttpError(WebView v,WebResourceRequest req, WebResourceResponse res){if(req.isForMainFrame())fail();}
            @Override public void onReceivedError(WebView v,WebResourceRequest req,WebResourceError err){if(req.isForMainFrame())fail();}
            @Override public void onPageCommitVisible(WebView v,String url){prepareFirstFrame();}
            @Override public void onPageFinished(WebView v,String url){prepareFirstFrame();}
        });
        channel.setMethodCallHandler((call,result)->{
            if("start".equals(call.method)||"retry".equals(call.method)){
                readerDark=Boolean.TRUE.equals(call.argument("dark"));
                disableMotion=Boolean.TRUE.equals(call.argument("reduce"));
                web.setBackgroundColor(background());
                navigation++;
                preparing=false;
                failed=false;
                if(path.matches("/[a-z0-9/-]+"))web.loadUrl("https://"+HOST+path);result.success(null);
            }else if("playText".equals(call.method)){
                web.evaluateJavascript("window.wikiReaderPlay?.(" + Boolean.TRUE.equals(call.arguments) + ");",null);
                result.success(null);
            }else if("theme".equals(call.method) && call.arguments instanceof Boolean){
                readerDark=(Boolean)call.arguments;
                web.setBackgroundColor(background());
                String mode=readerDark?"dark":"light";
                web.evaluateJavascript("localStorage.setItem('nuxt-color-mode','"+mode+"');document.documentElement.classList.remove('light','dark');document.documentElement.classList.add('"+mode+"');window.dispatchEvent(new StorageEvent('storage',{key:'nuxt-color-mode',newValue:'"+mode+"'}));",null);
                result.success(null);
            }else result.notImplemented();
        });
    }
    @Override public View getView(){return web;}
    @Override public void dispose(){disposed=true;channel.setMethodCallHandler(null);web.stopLoading();web.destroy();}
}
