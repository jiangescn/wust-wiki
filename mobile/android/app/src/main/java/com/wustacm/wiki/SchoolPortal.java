package com.wustacm.wiki;

import android.content.Context;
import android.net.Uri;
import android.net.http.SslError;
import android.view.Gravity;
import android.view.View;
import android.webkit.SslErrorHandler;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import io.flutter.plugin.platform.PlatformView;
import java.io.ByteArrayInputStream;
import java.util.Collections;
import java.util.Arrays;
import java.util.List;

final class SchoolPortal implements PlatformView {
    private static final String AUTH_HOST = "auth.wust.edu.cn";
    private static final String TEACHING_HOST = "bkjx.wust.edu.cn";
    private final FrameLayout content;
    private final WebView web;
    private final ProgressBar loading;
    private final List<String> hosts;

    SchoolPortal(Context context, String address) {
        this(context, address, AUTH_HOST, Arrays.asList(AUTH_HOST, TEACHING_HOST),
                "学校认证页面加载失败，可用系统浏览器打开或使用扫码。");
    }

    static SchoolPortal campusService(Context context, Object service) {
        String key = service instanceof String ? (String) service : "";
        String address = switch (key) {
            case "library" -> "https://libsys.wust.edu.cn/space/reader/readerHome";
            case "shuttle" -> "https://portal.wust.edu.cn/";
            case "second-class" -> "https://xg.wust.edu.cn/xsfw/sys/dektapp/*default/index.do";
            default -> null;
        };
        String host = address == null ? "" : Uri.parse(address).getHost();
        return new SchoolPortal(context, address, host, Arrays.asList(AUTH_HOST, host),
                "学校服务暂时打不开。可用右上角在浏览器打开。");
    }

    private SchoolPortal(Context context, String address, String initialHost,
                         List<String> hosts, String errorText) {
        this.hosts = hosts;
        content = new FrameLayout(context);
        web = new WebView(context);
        loading = new ProgressBar(context);
        content.addView(web, new FrameLayout.LayoutParams(-1, -1));
        content.addView(loading, new FrameLayout.LayoutParams(-2, -2, Gravity.CENTER));
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setCacheMode(WebSettings.LOAD_NO_CACHE);
        settings.setSupportMultipleWindows(false);
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                if (!request.isForMainFrame() || allowed(request.getUrl())) return false;
                showError(errorText);
                return true;
            }

            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                if (request.isForMainFrame() && !allowed(request.getUrl())) {
                    return new WebResourceResponse("text/plain", "UTF-8", 403, "Forbidden",
                            Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
                }
                return null;
            }

            @Override
            public void onPageCommitVisible(WebView view, String url) {
                loading.setVisibility(View.GONE);
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) showError(errorText);
            }

            @Override
            public void onReceivedHttpError(WebView view, WebResourceRequest request, WebResourceResponse response) {
                if (request.isForMainFrame()) showError(errorText);
            }

            @Override
            public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
                handler.cancel();
            }
        });
        Uri initial = address == null ? null : Uri.parse(address);
        if (initial == null || !initialHost.equals(initial.getHost()) || !allowed(initial)) {
            showError(errorText);
        } else {
            web.loadUrl(address);
        }
    }

    private boolean allowed(Uri uri) {
        return "https".equals(uri.getScheme())
                && uri.getHost() != null && hosts.contains(uri.getHost())
                && uri.getUserInfo() == null
                && (uri.getPort() == -1 || uri.getPort() == 443);
    }

    private void showError(String text) {
        if (web.getVisibility() == View.GONE) return;
        web.setVisibility(View.GONE);
        loading.setVisibility(View.GONE);
        TextView message = new TextView(content.getContext());
        message.setText(text);
        message.setGravity(Gravity.CENTER);
        content.addView(message, new FrameLayout.LayoutParams(-1, -2, Gravity.CENTER));
    }

    @Override public View getView() { return content; }

    @Override public void dispose() {
        web.stopLoading();
        content.removeView(web);
        web.destroy();
    }
}
