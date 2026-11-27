package com.wustacm.wiki;

import android.content.*;
import android.net.Uri;
import android.os.*;
import android.view.View;
import android.webkit.*;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.*;
import io.flutter.plugin.platform.*;
import java.util.Map;
import org.json.*;

public final class MainActivity extends FlutterActivity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private SharedPreferences prefs;
    private SharedPreferences countdowns;
    private NativeCapabilities capabilities;
    private WikiUpdateInstaller updater;
    @Override public String getInitialRoute() {
        if((getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE)!=0 && getIntent().getBooleanExtra("foundationAuthProbe",false)) {
            String mode=getIntent().getStringExtra("probeMode");
            if(!java.util.Arrays.asList("restore","expire","warm","queries","additional","identity","campus","slider","slider-service","files","capabilities").contains(mode)) mode="restore";
            return "/foundation-auth-probe/"+mode;
        }
        return super.getInitialRoute();
    }
    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        prefs = getSharedPreferences("native-wiki", MODE_PRIVATE);
        countdowns = getSharedPreferences("wiki-countdowns", MODE_PRIVATE);
        updater = new WikiUpdateInstaller(this);
        try { capabilities = new NativeCapabilities(this); }
        catch(Exception error) { throw new IllegalStateException("无法初始化安卓能力插件",error); }
        BinaryMessenger messenger = engine.getDartExecutor().getBinaryMessenger();
        new MethodChannel(messenger,"wiki/native").setMethodCallHandler((call,result)->{
            switch(call.method){
                case "foundationCapability": {
                    if (!(call.arguments instanceof Map<?,?>)) { result.error("invalid_arguments","平台参数无效。",null); break; }
                    JSONObject args=new JSONObject((Map<?,?>)call.arguments);
                    String operation=args.optString("operation"); args.remove("operation");
                    capabilities.request(operation,args,new NativeCapabilities.Callback() {
                        public void complete(JSONObject value) { handler.post(()->{try{result.success(jsonValue(value));}catch(JSONException error){result.error("invalid_response","平台响应无效。",null);}}); }
                        public void failed(String code) { handler.post(()->result.error(code,"安卓能力调用未完成。",null)); }
                    }); break;
                }
                case "restore": restore(result); break;
                case "loadAppearance": {
                    Map<String,Object> appearance = new java.util.HashMap<>();
                    appearance.put("theme", prefs.getString("appearanceTheme", "system"));
                    appearance.put("lowPerformance", prefs.getBoolean("lowPerformance", false));
                    appearance.put("openScheduleOnLaunch", prefs.getBoolean("openScheduleOnLaunch", false));
                    result.success(appearance);
                    break;
                }
                case "saveAppearance":
                    String theme = call.argument("theme");
                    if (!"light".equals(theme) && !"dark".equals(theme)) theme = "system";
                    prefs.edit()
                        .putString("appearanceTheme", theme)
                        .putBoolean("lowPerformance", Boolean.TRUE.equals(call.argument("lowPerformance")))
                        .putBoolean("openScheduleOnLaunch", Boolean.TRUE.equals(call.argument("openScheduleOnLaunch")))
                        .apply();
                    result.success(null);
                    break;
                case "wikiUpdateInfo": updater.info(result); break;
                case "recordWikiUpdateCheck": updater.recordCheck(); result.success(null); break;
                case "installWikiUpdate":
                    updater.install(call.argument("versionCode"), Boolean.TRUE.equals(call.argument("openSettings")), result);
                    break;
                case "loadCountdowns": result.success(countdowns.getString("items", "[]")); break;
                case "loadPersonalSchedule":
                    result.success(prefs.getString("personalSchedule", null));
                    break;
                case "savePersonalSchedule":
                    if (!(call.arguments instanceof String schedule)) {
                        result.error("invalid_arguments", "课程数据无效。", null);
                        break;
                    }
                    new Thread(() -> {
                        boolean saved = prefs.edit().putString("personalSchedule", schedule).commit();
                        handler.post(() -> {
                            if (saved) result.success(null);
                            else result.error("save_failed", "课程保存失败。", null);
                        });
                    }, "save-personal-schedule").start();
                    break;
                case "saveCountdowns":
                    if (call.arguments instanceof String items) {
                        countdowns.edit().putString("items", items).apply();
                        result.success(null);
                    } else {
                        result.error("invalid_arguments", "倒计时数据无效。", null);
                    }
                    break;
                case "save":
                    SharedPreferences.Editor edit=prefs.edit();
                    for(String key:new String[]{
                        "token","snapshot","campus","pinnedHomeTools",
                        "laundryShopId","laundryShopName","laundryShopFilter"
                    }){
                        String value=call.argument(key);
                        if(value!=null)edit.putString(key,value);
                    }
                    Number expiry=call.argument("expires");if(expiry!=null)edit.putLong("expires",expiry.longValue());
                    edit.apply();result.success(null);break;
                case "wechat":
                    AcademicWechat.open(this,call.argument("qr"),call.argument("mode"));result.success(null);break;
                case "external":
                    Uri uri=Uri.parse((String)call.arguments);
                    if(!"https".equals(uri.getScheme())&&!"http".equals(uri.getScheme())){result.success(false);break;}
                    try{startActivity(new Intent(Intent.ACTION_VIEW,uri));result.success(true);}
                    catch(ActivityNotFoundException e){result.success(false);}break;
                default:result.notImplemented();
            }
        });
        ArticleReader.resources(this);
        engine.getPlatformViewsController().getRegistry().registerViewFactory("wiki/article",new PlatformViewFactory(StandardMessageCodec.INSTANCE){
            @Override public PlatformView create(Context context,int id,Object args){
                Map<?,?> values=(Map<?,?>)args;
                return new ArticleReader(context,new MethodChannel(messenger,"wiki/article/"+id),(String)values.get("path"),Boolean.TRUE.equals(values.get("dark")));
            }
        });
        engine.getPlatformViewsController().getRegistry().registerViewFactory("wiki/dorm",new PlatformViewFactory(StandardMessageCodec.INSTANCE){
            @Override public PlatformView create(Context context,int id,Object args){
                return new Dorm(context,new MethodChannel(messenger,"wiki/dorm/"+id),(Map<?,?>)args);
            }
        });
        engine.getPlatformViewsController().getRegistry().registerViewFactory("wiki/school-portal",new PlatformViewFactory(StandardMessageCodec.INSTANCE){
            @Override public PlatformView create(Context context,int id,Object args){
                return new SchoolPortal(context,args instanceof String?(String)args:null);
            }
        });
        engine.getPlatformViewsController().getRegistry().registerViewFactory("wiki/school-service",new PlatformViewFactory(StandardMessageCodec.INSTANCE){
            @Override public PlatformView create(Context context,int id,Object args){
                return SchoolPortal.campusService(context,args);
            }
        });
    }
    private static void configure(WebView w){
        w.getSettings().setJavaScriptEnabled(true);
        w.getSettings().setAllowFileAccess(false);
        w.getSettings().setAllowContentAccess(false);
        w.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
    }
    private void restore(MethodChannel.Result result){
        if(prefs.getBoolean("migrated",false)){restoreResult(result);return;}
        WebView w=new WebView(this);configure(w);w.getSettings().setDomStorageEnabled(true);
        boolean[] finished={false};
        Runnable finish=()->{if(finished[0])return;finished[0]=true;w.destroy();restoreResult(result);};
        handler.postDelayed(finish,4500);
        w.setWebViewClient(new WebViewClient(){
            @Override public void onPageFinished(WebView view,String url){
                if(finished[0])return;
                view.evaluateJavascript("(()=>[localStorage.getItem('wust-wiki:schedule:v1'),localStorage.getItem('wust-wiki:academic-session:v1:https://schedule.wiki.jianges.com')])()",raw->{
                    if(finished[0])return;
                    try{
                        JSONArray data=new JSONArray(raw);SharedPreferences.Editor edit=prefs.edit();
                        if(!prefs.contains("snapshot")&&!data.isNull(0))edit.putString("snapshot",data.getString(0));
                        if(!prefs.contains("token")&&!data.isNull(1)){
                            JSONObject session=new JSONObject(data.getString(1));long end=session.optLong("expiresAt"),now=System.currentTimeMillis();
                            if(session.optString("token").matches("[a-f0-9]{64}")&&end>now&&end<=now+86400000L)edit.putString("token",session.getString("token")).putLong("expires",end);
                        }
                        edit.putBoolean("migrated",true).apply();
                    }catch(JSONException ignored){}
                    handler.removeCallbacks(finish);finish.run();
                });
            }
        });
        w.loadDataWithBaseURL("https://wiki.wustacm.com/","<meta charset=utf-8>","text/html","utf-8",null);
    }
    private void restoreResult(MethodChannel.Result result) {
        Map<String,Object> values = new java.util.HashMap<>(prefs.getAll());
        values.put("localAvailable", true);
        try { values.put("localSaved", capabilities != null && capabilities.hasSavedAccount()); }
        catch (Exception error) { values.put("localSaved", false); }
        result.success(values);
    }
    private static Object jsonValue(Object value) throws JSONException {
        if (value == JSONObject.NULL) return null;
        if (value instanceof JSONObject object) {
            Map<String,Object> map = new java.util.HashMap<>();
            java.util.Iterator<String> keys = object.keys();
            while (keys.hasNext()) { String key = keys.next(); map.put(key, jsonValue(object.get(key))); }
            return map;
        }
        if (value instanceof JSONArray array) {
            java.util.List<Object> list = new java.util.ArrayList<>();
            for (int i=0;i<array.length();i++) list.add(jsonValue(array.get(i)));
            return list;
        }
        return value;
    }
    @Override protected void onActivityResult(int requestCode,int resultCode,Intent data) {
        if(updater!=null && updater.onActivityResult(requestCode)) return;
        if(capabilities!=null && capabilities.onActivityResult(requestCode,resultCode,data)) return;
        super.onActivityResult(requestCode,resultCode,data);
    }
    @Override protected void onDestroy() { if(capabilities!=null)capabilities.close(); super.onDestroy(); }
    private static final class Dorm implements PlatformView{
        private final WebView web;
        private final MethodChannel channel;
        private String error="";
        private boolean disposed=false;
        Dorm(Context context, MethodChannel channel,Map<?,?> args){
            this.channel=channel;web=new WebView(context);configure(web);web.getSettings().setDomStorageEnabled(true);
            String area=String.valueOf(args.get("area")),room=String.valueOf(args.get("room"));
            channel.setMethodCallHandler((call,result)->{
                if(!call.method.equals("status")){result.notImplemented();return;}
                if(!error.isEmpty()){result.success(error);return;}
                web.evaluateJavascript("document.querySelector('#query-status[data-state]')?.textContent ? Array.from(document.querySelector('#query-status').children,e=>e.textContent).join('\\n') : ''",raw->{
                    try{Object text=new JSONTokener(raw).nextValue();result.success(text instanceof String?text:"");}
                    catch(JSONException e){result.success("");}
                });
            });
            if(!area.matches("[A-D]")||!room.matches("[0-9]{3,16}")){error="请检查区域和完整寝室号。";return;}
            web.setWebViewClient(new WebViewClient(){
                @Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest r){return r.isForMainFrame()&&!"https://dorm.wustacm.com/".equals(r.getUrl().toString());}
                @Override public void onReceivedError(WebView v,WebResourceRequest r,WebResourceError e){if(r.isForMainFrame())error="无法连接宿舍查询服务，请重试。";}
                @Override public void onPageFinished(WebView v,String url){
                    if(disposed||!"https://dorm.wustacm.com/".equals(url))return;
                    v.evaluateJavascript("(()=>{const f=document.querySelector('#query-form');if(!f)return false;document.querySelector('.page-shell').style.display='none';document.querySelector('#area').value="+JSONObject.quote(area)+";document.querySelector('#room').value="+JSONObject.quote(room)+";let tries=0;const t=setInterval(()=>{if(typeof captchaReady!=='undefined'&&captchaReady){clearInterval(t);f.requestSubmit()}else if(++tries>=80){clearInterval(t);document.querySelector('#query-status').dataset.state='error';const p=document.createElement('p');p.textContent='验证组件加载失败，请重新查询。';document.querySelector('#query-status').append(p)}},250);return true})()",out->{if(!"true".equals(out))error="宿舍验证页面暂不可用。";});
                }
            });
            web.loadUrl("https://dorm.wustacm.com/");
        }
        @Override public View getView(){return web;}
        @Override public void dispose(){disposed=true;channel.setMethodCallHandler(null);web.stopLoading();web.destroy();}
    }
}
