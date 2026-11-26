package com.wustacm.wiki;

import android.app.Activity;
import android.os.*;
import android.graphics.*;
import android.graphics.pdf.PdfRenderer;
import android.widget.*;
import java.io.File;

public class PdfActivity extends Activity {
    private PdfRenderer renderer;
    private int index;
    private ImageView image;
    private TextView page;
    private Bitmap bitmap;
    private Button previous, next;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        String name=getIntent().getStringExtra("name");
        setTitle(name==null?"PDF 预览":name);
        LinearLayout layout = new LinearLayout(this); layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(12, 60, 12, 60);
        LinearLayout controls = new LinearLayout(this);
        previous = new Button(this); previous.setText("上一页"); previous.setOnClickListener(view -> show(index - 1));
        page = new TextView(this);
        next = new Button(this); next.setText("下一页"); next.setOnClickListener(view -> show(index + 1));
        controls.addView(previous); controls.addView(page); controls.addView(next); layout.addView(controls);
        ScrollView scroll = new ScrollView(this); image = new ImageView(this); image.setAdjustViewBounds(true);
        scroll.addView(image); layout.addView(scroll,new LinearLayout.LayoutParams(-1,0,1)); setContentView(layout);
        ParcelFileDescriptor descriptor=null;
        try {
            descriptor=ParcelFileDescriptor.open(new File(getCacheDir(), "notice.pdf"), ParcelFileDescriptor.MODE_READ_ONLY);
            renderer = new PdfRenderer(descriptor); descriptor=null;
            if(renderer.getPageCount()<1) throw new IllegalStateException();
            show(state == null ? 0 : Math.min(state.getInt("page"),renderer.getPageCount()-1));
        } catch (Exception error) { page.setText("PDF 预览失败"); previous.setEnabled(false); next.setEnabled(false); }
        finally { if(descriptor!=null) try { descriptor.close(); } catch(Exception ignored) {} }
    }
    private void show(int selected) {
        if (renderer == null || selected < 0 || selected >= renderer.getPageCount()) return;
        Bitmap rendered=null;
        try (PdfRenderer.Page current = renderer.openPage(selected)) {
            int sourceWidth=current.getWidth(),sourceHeight=current.getHeight();
            if(sourceWidth<1 || sourceHeight<1) throw new IllegalArgumentException();
            double scale=Math.min((double)Math.max(1,Math.min(1600,getResources().getDisplayMetrics().widthPixels))/sourceWidth,
                Math.min(8192.0/sourceHeight,Math.sqrt(8000000.0/sourceWidth/sourceHeight)));
            int width=Math.max(1,(int)(sourceWidth*scale)),height=Math.max(1,(int)(sourceHeight*scale));
            rendered = Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888);
            rendered.eraseColor(Color.WHITE); current.render(rendered, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);
            image.setImageBitmap(rendered); if (bitmap != null) bitmap.recycle(); bitmap = rendered; rendered=null;
            index=selected;
            page.setText((index + 1) + " / " + renderer.getPageCount());
            previous.setEnabled(index>0); next.setEnabled(index+1<renderer.getPageCount());
        } catch(Exception | OutOfMemoryError error) { page.setText("此页无法预览"); }
        finally { if(rendered!=null) rendered.recycle(); }
    }
    @Override public void onSaveInstanceState(Bundle state) { state.putInt("page", index); super.onSaveInstanceState(state); }
    @Override protected void onDestroy() { if (renderer != null) renderer.close(); if (bitmap != null) bitmap.recycle(); super.onDestroy(); }
}
