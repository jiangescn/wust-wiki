package com.wustacm.wiki;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.ContentValues;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.WebView;
import android.widget.Toast;
import com.google.zxing.BinaryBitmap;
import com.google.zxing.RGBLuminanceSource;
import com.google.zxing.common.HybridBinarizer;
import com.google.zxing.qrcode.QRCodeReader;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.UUID;
import org.json.JSONTokener;

final class AcademicWechat {
    private static final String WECHAT = "com.tencent.mm";
    private static final String PNG = "data:image/png;base64,";
    static void open(Activity activity, String src, String mode) {
        if (!"confirm".equals(mode) && !"album".equals(mode)) return;
        if ("album".equals(mode) && Build.VERSION.SDK_INT < 29) {
            message(activity, "请先截图，再到微信扫一扫中选择相册里的二维码。确认后手动切回 Wiki。");
            return;
        }
        if ("album".equals(mode)) {
            new AlertDialog.Builder(activity).setTitle("用微信相册识别")
                .setMessage("将本次学校登录码保存到相册并打开微信。请在「扫一扫 → 相册」选择最新二维码，确认后手动切回 Wiki。")
                .setNegativeButton("取消", null)
                .setPositiveButton("保存并打开微信", (d, which) -> read(activity, src, true)).show();
        } else read(activity, src, false);
    }

    private static void read(Activity activity, String src, boolean album) {
            try {
                if (src == null || !src.startsWith(PNG) || src.length() > 512000)
                    throw new IllegalArgumentException();
                byte[] image = Base64.decode(src.substring(PNG.length()), Base64.DEFAULT);
                Uri link = schoolLink(image);
                if (album) {
                    Intent launcher = activity.getPackageManager().getLaunchIntentForPackage(WECHAT);
                    if (launcher == null) { message(activity, "未找到可打开的微信，请检查微信是否已安装。"); return; }
                    saveImage(activity, image);
                    activity.startActivity(launcher);
                } else {
                    Intent confirm = new Intent(Intent.ACTION_VIEW, link).setPackage(WECHAT);
                    activity.startActivity(confirm);
                }
            } catch (ActivityNotFoundException | SecurityException unavailable) {
                if(album){message(activity,"当前无法打开微信，请用微信扫一扫识别相册中的登录码。");}
                else if(activity.getPackageManager().getLaunchIntentForPackage(WECHAT)!=null){open(activity,src,"album");}
                else{new AlertDialog.Builder(activity).setTitle("未找到微信").setMessage("可以用另一台设备扫描当前学校二维码。").setPositiveButton("返回二维码",null).show();}
            } catch (IOException storage) {
                message(activity, "保存失败。请截图后用微信扫一扫从相册识别。");
            } catch (Exception invalid) {
                message(activity, "未读到有效的学校登录码，请重新生成后再试。");
            }
    }

    private static Uri schoolLink(byte[] image) throws Exception {
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        BitmapFactory.decodeByteArray(image, 0, image.length, options);
        if (options.outWidth < 1 || options.outHeight < 1 || options.outWidth > 1200 || options.outHeight > 1200)
            throw new IllegalArgumentException();
        Bitmap bitmap = BitmapFactory.decodeByteArray(image, 0, image.length);
        int w = bitmap.getWidth(), h = bitmap.getHeight();
        int[] pixels = new int[w*h];
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h);
        bitmap.recycle();
        BinaryBitmap qr = new BinaryBitmap(new HybridBinarizer(new RGBLuminanceSource(w, h, pixels)));
        Uri link = Uri.parse(new QRCodeReader().decode(qr).getText());
        if (!"https".equals(link.getScheme())) throw new IllegalArgumentException();
        boolean portalLink = "auth.wust.edu.cn".equals(link.getEncodedAuthority())
                && "/authserver/qrCode/qrCodeLogin.do".equals(link.getEncodedPath())
                && link.getQueryParameter("uuid") != null;
        boolean wechatLink = "open.weixin.qq.com".equals(link.getEncodedAuthority())
                && "/connect/oauth2/authorize".equals(link.getEncodedPath())
                && link.getQueryParameter("state") != null && link.getQueryParameter("appid") != null;
        if (!portalLink && !wechatLink) throw new IllegalArgumentException();
        return link;
    }

    private static void saveImage(Activity activity, byte[] image) throws IOException {
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, "WUST-Wiki-" + UUID.randomUUID() + ".png");
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
        values.put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/WUST Wiki");
        values.put(MediaStore.Images.Media.IS_PENDING, 1);
        Uri uri = activity.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) throw new IOException();
        try {
            try (OutputStream out = activity.getContentResolver().openOutputStream(uri)) {
                if (out == null) throw new IOException();
                out.write(image);
            }
            values.clear();
            values.put(MediaStore.Images.Media.IS_PENDING, 0);
            if (activity.getContentResolver().update(uri, values, null, null) != 1) throw new IOException();
        } catch (IOException | RuntimeException e) {
            activity.getContentResolver().delete(uri, null, null);
            throw e;
        }
    }

    private static void message(Activity activity, String text) {
        Toast.makeText(activity, text, Toast.LENGTH_LONG).show();
    }
}
