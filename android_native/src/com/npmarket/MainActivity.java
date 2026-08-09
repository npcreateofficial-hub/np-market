package com.npmarket;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Locale;

public class MainActivity extends Activity {
    private static final String[] API_URLS = new String[] {
            "https://np-market.np-class.com/api/products"
    };
    private static final int RED = Color.rgb(167, 15, 40);
    private static final int RED_DARK = Color.rgb(112, 8, 24);
    private static final int GOLD = Color.rgb(196, 131, 43);
    private static final int BG = Color.rgb(255, 251, 248);
    private static final int LINE = Color.rgb(232, 224, 218);
    private static final int SOFT = Color.rgb(255, 243, 238);
    private static final int TEXT_MUTED = Color.rgb(105, 104, 104);

    private final Handler main = new Handler(Looper.getMainLooper());
    private final ArrayList<JSONObject> products = new ArrayList<>();
    private final ArrayList<String> favoriteIds = new ArrayList<>();
    private LinearLayout content;
    private LinearLayout nav;
    private int tab = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(Color.WHITE);
        loadFavorites();
        showShell();
        loadProducts();
    }

    private void showShell() {
        LinearLayout root = column();
        root.setBackgroundColor(BG);
        content = column();
        root.addView(content, new LinearLayout.LayoutParams(-1, 0, 1));
        nav = row();
        nav.setGravity(Gravity.CENTER);
        nav.setPadding(dp(8), dp(4), dp(8), dp(22));
        nav.setBackgroundColor(Color.WHITE);
        root.addView(nav, new LinearLayout.LayoutParams(-1, dp(88)));
        setContentView(root);
        render();
    }

    private void loadProducts() {
        loading();
        new Thread(new Runnable() {
            @Override public void run() {
                try {
                JSONObject body = fetchProductsBody();
                    JSONArray arr = body.optJSONArray("products");
                    ArrayList<JSONObject> fresh = new ArrayList<>();
                    if (arr != null) {
                        for (int i = 0; i < arr.length(); i++) {
                            JSONObject item = arr.getJSONObject(i);
                            if (bestOffer(item.optJSONArray("offers")) != null) {
                                fresh.add(item);
                            }
                        }
                    }
                    main.post(new Runnable() {
                        @Override public void run() {
                            products.clear();
                            products.addAll(fresh);
                            render();
                        }
                    });
                } catch (Exception e) {
                    String msg = e.getMessage();
                    main.post(new Runnable() {
                        @Override public void run() {
                            error("โหลดข้อมูลไม่สำเร็จ", msg == null ? "" : msg);
                        }
                    });
                }
            }
        }).start();
    }

    private void render() {
        if (content == null) return;
        content.removeAllViews();
        if (products.isEmpty()) {
            loading();
        } else if (tab == 0) {
            home();
        } else if (tab == 1) {
            catalog();
        } else if (tab == 2) {
            categories();
        } else if (tab == 3) {
            favorites();
        } else {
            help();
        }
        bottomNav();
    }

    private void loading() {
        if (content == null) return;
        content.removeAllViews();
        LinearLayout box = column();
        box.setGravity(Gravity.CENTER);
        box.setPadding(dp(20), dp(64), dp(20), dp(20));
        box.addView(brandHeader(false));
        box.addView(space(24));
        box.addView(text("กำลังโหลดสินค้า...", 22, Color.BLACK, true));
        box.addView(text("ดึงชื่อ รูป และราคาจากระบบหลังบ้าน", 14, TEXT_MUTED, false));
        content.addView(box, new LinearLayout.LayoutParams(-1, -1));
    }

    private void error(String title, String body) {
        content.removeAllViews();
        LinearLayout box = column();
        box.setPadding(dp(18), dp(36), dp(18), dp(18));
        box.addView(brandHeader(false));
        box.addView(space(20));
        box.addView(text(title, 24, Color.BLACK, true));
        box.addView(text(body, 14, TEXT_MUTED, false));
        box.addView(space(16));
        Button retry = primaryButton("โหลดใหม่");
        retry.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { loadProducts(); }
        });
        box.addView(retry);
        content.addView(box, new LinearLayout.LayoutParams(-1, -1));
    }

    private void home() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = column();
        root.setPadding(dp(16), dp(22), dp(16), dp(96));
        scroll.addView(root);
        root.addView(brandHeader(false));
        root.addView(space(16));
        root.addView(chips());
        root.addView(space(16));
        root.addView(promo());
        root.addView(space(22));
        root.addView(section("ดีลแนะนำวันนี้", "ดูทั้งหมด", new View.OnClickListener() {
            @Override public void onClick(View v) { tab = 1; render(); }
        }));
        root.addView(space(8));
        root.addView(featuredRow());
        root.addView(space(22));
        root.addView(section("เปรียบเทียบราคายอดนิยม", "ดูทั้งหมด", new View.OnClickListener() {
            @Override public void onClick(View v) { tab = 1; render(); }
        }));
        root.addView(space(8));
        for (JSONObject p : products) root.addView(compareCard(p));
        content.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
    }

    private void catalog() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = column();
        root.setPadding(dp(14), dp(22), dp(14), dp(96));
        scroll.addView(root);
        root.addView(brandHeader(false));
        root.addView(space(14));
        root.addView(searchBar("ค้นหาสินค้าหรือแบรนด์..."));
        root.addView(space(12));
        root.addView(chips());
        root.addView(space(12));
        LinearLayout filters = row();
        filters.addView(tinyChip("เรียงตามราคาต่ำสุด", true));
        filters.addView(spaceW(8));
        filters.addView(tinyChip(products.size() + " รายการ", false));
        root.addView(filters);
        root.addView(space(12));
        for (JSONObject p : products) root.addView(listCard(p));
        content.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
    }

    private void categories() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = column();
        root.setPadding(dp(16), dp(22), dp(16), dp(96));
        scroll.addView(root);
        root.addView(brandHeader(false));
        root.addView(space(14));
        root.addView(searchBar("ค้นหาหมวดหมู่..."));
        root.addView(space(18));
        LinearLayout card = card();
        card.addView(categoryBlock("แฟชั่นผู้หญิง", products.size() + " รายการ", new String[]{"เสื้อ", "ร้านค้า", "ดูทั้งหมด"}));
        card.addView(categoryBlock("แพลตฟอร์ม", countPlatform() + " ลิงก์", new String[]{"Shopee", "TikTok", "ราคาดี"}));
        card.addView(categoryBlock("ดีลราคาต่ำ", products.size() + " รายการ", new String[]{"ถูกสุด", "อัปเดต", "เปรียบเทียบ"}));
        root.addView(card);
        content.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
    }

    private void help() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = column();
        root.setPadding(dp(16), dp(22), dp(16), dp(96));
        scroll.addView(root);
        root.addView(brandHeader(false));
        root.addView(space(22));
        root.addView(text("หัวข้อช่วยเหลือด่วน", 20, Color.BLACK, true));
        root.addView(space(10));
        LinearLayout grid = row();
        grid.addView(helpBox("วิธีใช้งาน", "เริ่มต้นใช้งาน NP Market"), new LinearLayout.LayoutParams(0, dp(96), 1));
        grid.addView(spaceW(10));
        grid.addView(helpBox("เปรียบเทียบราคา", "เทียบราคาหลายร้าน"), new LinearLayout.LayoutParams(0, dp(96), 1));
        root.addView(grid);
        root.addView(space(10));
        LinearLayout grid2 = row();
        grid2.addView(helpBox("การสั่งซื้อ", "กดไปซื้อที่แพลตฟอร์ม"), new LinearLayout.LayoutParams(0, dp(96), 1));
        grid2.addView(spaceW(10));
        grid2.addView(helpBox("ติดต่อทีมงาน", "สอบถามและแจ้งปัญหา"), new LinearLayout.LayoutParams(0, dp(96), 1));
        root.addView(grid2);
        root.addView(space(24));
        root.addView(text("คำถามที่พบบ่อย", 20, Color.BLACK, true));
        root.addView(space(10));
        root.addView(faq("NP Market คืออะไร?"));
        root.addView(faq("เปรียบเทียบราคาอย่างไร?"));
        root.addView(faq("ราคามาจากไหน?"));
        root.addView(faq("ถ้าราคาเปลี่ยนต้องทำอย่างไร?"));
        content.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
    }

    private void favorites() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = column();
        root.setPadding(dp(16), dp(22), dp(16), dp(96));
        scroll.addView(root);
        root.addView(brandHeader(false));
        root.addView(space(14));
        root.addView(searchBar("ค้นหาสินค้าที่ถูกใจ..."));
        root.addView(space(18));
        root.addView(text("สินค้าที่ถูกใจ", 24, Color.BLACK, true));
        root.addView(text(favoriteProducts().size() + " / 100 รายการ", 14, TEXT_MUTED, false));
        root.addView(space(12));
        ArrayList<JSONObject> favs = favoriteProducts();
        if (favs.isEmpty()) {
            LinearLayout empty = card();
            empty.setGravity(Gravity.CENTER);
            empty.addView(text("♡", 34, RED, true));
            empty.addView(space(8));
            TextView title = text("ยังไม่มีสินค้าที่ถูกใจ", 20, Color.BLACK, true);
            title.setGravity(Gravity.CENTER);
            empty.addView(title);
            TextView body = text("กดหัวใจในหน้าสินค้า เพื่อเก็บไว้กลับมาดูทีหลัง", 14, TEXT_MUTED, false);
            body.setGravity(Gravity.CENTER);
            empty.addView(body);
            root.addView(empty);
        } else {
            for (JSONObject p : favs) root.addView(listCard(p));
        }
        content.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
    }

    private LinearLayout brandHeader(boolean menu) {
        LinearLayout h = row();
        TextView logo = text("NP", 18, Color.WHITE, true);
        logo.setGravity(Gravity.CENTER);
        logo.setBackground(round(RED, 8));
        h.addView(logo, new LinearLayout.LayoutParams(dp(40), dp(40)));
        LinearLayout b = column();
        b.setPadding(dp(9), 0, 0, 0);
        b.addView(text("NP MARKET", 18, Color.BLACK, true));
        b.addView(text("เปรียบเทียบราคาง่าย", 12, TEXT_MUTED, false));
        h.addView(b, new LinearLayout.LayoutParams(0, -2, 1));
        return h;
    }

    private View searchBar(String hint) {
        LinearLayout s = row();
        s.setPadding(dp(12), 0, dp(10), 0);
        s.setBackground(stroke(Color.WHITE, LINE, 8));
        s.addView(text("⌕", 30, Color.BLACK, false));
        TextView label = text(hint, 15, Color.rgb(145, 145, 145), false);
        label.setPadding(dp(8), 0, 0, dp(1));
        s.addView(label, new LinearLayout.LayoutParams(0, -2, 1));
        s.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { tab = 1; render(); }
        });
        s.setLayoutParams(new LinearLayout.LayoutParams(-1, dp(50)));
        return s;
    }

    private View chips() {
        HorizontalScrollView hsv = new HorizontalScrollView(this);
        hsv.setHorizontalScrollBarEnabled(false);
        LinearLayout row = row();
        row.addView(tinyChip("ทั้งหมด", true));
        row.addView(spaceW(8));
        row.addView(tinyChip("แฟชั่นผู้หญิง", false));
        row.addView(spaceW(8));
        row.addView(tinyChip("Shopee", false));
        row.addView(spaceW(8));
        row.addView(tinyChip("TikTok Shop", false));
        row.addView(spaceW(8));
        row.addView(tinyChip("...", false));
        hsv.addView(row);
        return hsv;
    }

    private TextView tinyChip(String label, boolean selected) {
        TextView chip = text(label, 14, selected ? Color.WHITE : Color.BLACK, true);
        chip.setGravity(Gravity.CENTER);
        chip.setPadding(dp(12), 0, dp(12), 0);
        chip.setBackground(selected ? round(RED, 22) : stroke(Color.WHITE, LINE, 22));
        chip.setMinHeight(dp(34));
        return chip;
    }

    private View promo() {
        LinearLayout p = row();
        p.setPadding(dp(14), dp(10), dp(12), dp(10));
        p.setBackground(stroke(SOFT, Color.rgb(244, 216, 201), 8));
        TextView gift = text("ดีล", 18, RED, true);
        gift.setGravity(Gravity.CENTER);
        gift.setBackground(round(Color.WHITE, 8));
        p.addView(gift, new LinearLayout.LayoutParams(dp(52), dp(52)));
        LinearLayout copy = column();
        copy.setPadding(dp(12), 0, 0, 0);
        copy.addView(text("ดีลเด่น ลดแรง ทุกวัน!", 18, Color.BLACK, true));
        copy.addView(text("รวมดีลเด่นจากหลายแพลตฟอร์ม", 13, TEXT_MUTED, false));
        p.addView(copy, new LinearLayout.LayoutParams(0, -2, 1));
        TextView see = text("ดูทั้งหมด ›", 13, RED, true);
        see.setGravity(Gravity.CENTER);
        see.setBackground(stroke(Color.WHITE, Color.rgb(244, 216, 201), 18));
        p.addView(see, new LinearLayout.LayoutParams(dp(84), dp(34)));
        return p;
    }

    private View section(String title, String action, View.OnClickListener listener) {
        LinearLayout r = row();
        r.addView(text(title, 21, Color.BLACK, true), new LinearLayout.LayoutParams(0, -2, 1));
        TextView a = text(action, 14, RED, true);
        a.setOnClickListener(listener);
        r.addView(a);
        return r;
    }

    private View featuredRow() {
        LinearLayout row = row();
        int take = Math.min(2, products.size());
        for (int i = 0; i < take; i++) {
            if (i > 0) row.addView(spaceW(10));
            row.addView(dealCard(products.get(i)), new LinearLayout.LayoutParams(0, dp(178), 1));
        }
        return row;
    }

    private View dealCard(JSONObject p) {
        LinearLayout card = card();
        card.setPadding(dp(10), dp(10), dp(10), dp(10));
        ImageView img = image(p.optString("image_url"), -1, dp(84), ImageView.ScaleType.CENTER_CROP);
        card.addView(img);
        card.addView(space(8));
        card.addView(text(p.optString("title"), 14, Color.BLACK, true, 2));
        card.addView(space(4));
        card.addView(text(baht(price(bestOffer(p.optJSONArray("offers")))), 17, RED, true));
        card.addView(space(4));
        card.addView(bestPlatformLine(p));
        card.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { detail(p); }
        });
        return card;
    }

    private View compareCard(JSONObject p) {
        LinearLayout card = card();
        card.setPadding(dp(12), dp(12), dp(12), dp(12));
        LinearLayout top = row();
        top.addView(image(p.optString("image_url"), dp(96), dp(104), ImageView.ScaleType.CENTER_CROP));
        LinearLayout info = column();
        info.setPadding(dp(12), 0, 0, 0);
        info.addView(text(p.optString("title"), 17, Color.BLACK, true, 2));
        info.addView(space(4));
        info.addView(text(p.optString("brand_name") + " · " + p.optString("category_name"), 13, TEXT_MUTED, false));
        info.addView(space(8));
        info.addView(text(baht(price(bestOffer(p.optJSONArray("offers")))), 21, RED, true));
        info.addView(space(6));
        info.addView(bestPlatformLine(p));
        top.addView(info, new LinearLayout.LayoutParams(0, -2, 1));
        top.addView(text("›", 28, Color.rgb(120, 120, 120), false));
        card.addView(top);
        card.addView(space(10));
        JSONArray offers = sortedOffers(p.optJSONArray("offers"));
        for (int i = 0; i < offers.length(); i++) card.addView(offerLine(offers.optJSONObject(i), false));
        card.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { detail(p); }
        });
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.setMargins(0, 0, 0, dp(12));
        card.setLayoutParams(lp);
        return card;
    }

    private View listCard(JSONObject p) {
        LinearLayout card = card();
        card.setPadding(dp(12), dp(12), dp(12), dp(12));
        LinearLayout r = row();
        r.addView(image(p.optString("image_url"), dp(104), dp(104), ImageView.ScaleType.CENTER_CROP));
        LinearLayout mid = column();
        mid.setPadding(dp(12), 0, 0, 0);
        mid.addView(text(p.optString("title"), 17, Color.BLACK, true, 2));
        mid.addView(text("เริ่มต้นเพียง", 12, TEXT_MUTED, false));
        mid.addView(text(baht(price(bestOffer(p.optJSONArray("offers")))), 21, RED, true));
        mid.addView(space(6));
        mid.addView(bestPlatformLine(p));
        r.addView(mid, new LinearLayout.LayoutParams(0, -2, 1));
        r.addView(text("›", 28, Color.rgb(120, 120, 120), false));
        card.addView(r);
        card.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { detail(p); }
        });
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.setMargins(0, 0, 0, dp(12));
        card.setLayoutParams(lp);
        return card;
    }

    private void detail(JSONObject p) {
        content.removeAllViews();
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = column();
        root.setPadding(dp(16), dp(22), dp(16), dp(104));
        scroll.addView(root);
        LinearLayout bar = row();
        bar.addView(iconButton("‹", new View.OnClickListener() {
            @Override public void onClick(View v) { render(); }
        }));
        LinearLayout b = column();
        b.setPadding(dp(8), 0, 0, 0);
        b.addView(text("NP MARKET", 17, RED, true));
        b.addView(text("เปรียบเทียบราคาง่าย", 12, TEXT_MUTED, false));
        bar.addView(b, new LinearLayout.LayoutParams(0, -2, 1));
        TextView heart = iconText(isFavorite(p) ? "♥" : "♡");
        heart.setTextColor(isFavorite(p) ? RED : Color.BLACK);
        heart.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                toggleFavorite(p);
                detail(p);
            }
        });
        bar.addView(heart, new LinearLayout.LayoutParams(dp(40), dp(40)));
        root.addView(bar);
        root.addView(space(14));
        root.addView(image(p.optString("image_url"), -1, dp(248), ImageView.ScaleType.FIT_CENTER));
        root.addView(space(14));
        root.addView(text(p.optString("title"), 21, Color.BLACK, true, 3));
        root.addView(space(6));
        root.addView(text(p.optString("brand_name") + " · " + p.optString("category_name"), 14, TEXT_MUTED, false));
        root.addView(space(8));
        root.addView(text("★ 4.8", 13, GOLD, true));
        root.addView(space(12));
        JSONArray offers = sortedOffers(p.optJSONArray("offers"));
        JSONObject best = offers.optJSONObject(0);
        root.addView(bestPanel(best));
        root.addView(space(18));
        root.addView(section("เปรียบเทียบราคาจากร้าน", "ดูทั้งหมด", null));
        root.addView(space(8));
        LinearLayout table = card();
        for (int i = 0; i < offers.length(); i++) table.addView(offerLine(offers.optJSONObject(i), true));
        root.addView(table);
        root.addView(space(14));
        root.addView(text("รายละเอียดสินค้า", 20, Color.BLACK, true));
        root.addView(space(6));
        root.addView(text(p.optString("description", "ข้อมูลสินค้าจาก API หลังบ้าน"), 14, Color.rgb(55, 55, 55), false));
        content.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
        bottomNav();
    }

    private View bestPanel(JSONObject offer) {
        LinearLayout box = card();
        box.setPadding(dp(10), dp(10), dp(10), dp(10));
        box.setBackground(stroke(Color.WHITE, Color.rgb(238, 205, 159), 8));

        LinearLayout r = row();
        r.setGravity(Gravity.CENTER_VERTICAL);
        r.addView(platformIcon(platform(offer), 40));

        LinearLayout mid = column();
        mid.setPadding(dp(10), 0, dp(8), 0);
        TextView badge = text("ราคาต่ำสุด", 11, Color.WHITE, true);
        badge.setGravity(Gravity.CENTER);
        badge.setBackground(round(RED, 14));
        mid.addView(badge, new LinearLayout.LayoutParams(dp(78), dp(24)));
        mid.addView(space(3));
        mid.addView(text(platformLabel(platform(offer)), 14, Color.BLACK, true));
        mid.addView(text(baht(price(offer)), 22, RED, true));
        r.addView(mid, new LinearLayout.LayoutParams(0, -2, 1));

        Button go = new Button(this);
        go.setText("ซื้อ ↗");
        go.setTextSize(15);
        go.setTextColor(Color.WHITE);
        go.setTypeface(Typeface.DEFAULT_BOLD);
        go.setAllCaps(false);
        go.setPadding(0, 0, 0, 0);
        go.setBackground(round(Color.rgb(38, 38, 38), 12));
        go.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { open(link(offer)); }
        });
        r.addView(go, new LinearLayout.LayoutParams(dp(92), dp(44)));
        box.addView(r);
        return box;
    }
    private View offerLine(JSONObject offer, boolean button) {
        LinearLayout r = row();
        r.setPadding(0, dp(10), 0, dp(10));
        r.addView(platformIcon(platform(offer), 36));
        TextView name = text(platformLabel(platform(offer)), 14, Color.BLACK, true);
        name.setPadding(dp(10), 0, 0, 0);
        r.addView(name, new LinearLayout.LayoutParams(0, -2, 1));
        r.addView(text(baht(price(offer)), 16, RED, true));
        if (button) {
            TextView go = text("  ›", 22, Color.rgb(120, 120, 120), false);
            r.addView(go);
        }
        r.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { open(link(offer)); }
        });
        return r;
    }

    private View bestPlatformLine(JSONObject p) {
        LinearLayout r = row();
        JSONObject best = bestOffer(p.optJSONArray("offers"));
        if (best != null) r.addView(platformIcon(platform(best), 24));
        return r;
    }

    private View tinyPlatformLine(JSONObject p) {
        HorizontalScrollView hsv = new HorizontalScrollView(this);
        hsv.setHorizontalScrollBarEnabled(false);
        LinearLayout r = row();
        JSONArray offers = p.optJSONArray("offers");
        if (offers != null) {
            for (int i = 0; i < offers.length(); i++) {
                if (i > 0) r.addView(spaceW(6));
                r.addView(platformIcon(platform(offers.optJSONObject(i)), 24));
            }
        }
        hsv.addView(r);
        return hsv;
    }
    private View categoryBlock(String title, String count, String[] items) {
        LinearLayout block = column();
        block.setPadding(0, 0, 0, dp(12));
        LinearLayout head = row();
        TextView icon = text("□", 24, Color.WHITE, true);
        icon.setGravity(Gravity.CENTER);
        icon.setBackground(round(RED, 24));
        head.addView(icon, new LinearLayout.LayoutParams(dp(48), dp(48)));
        LinearLayout copy = column();
        copy.setPadding(dp(12), 0, 0, 0);
        copy.addView(text(title, 20, Color.BLACK, true));
        copy.addView(text(count, 13, TEXT_MUTED, false));
        head.addView(copy, new LinearLayout.LayoutParams(0, -2, 1));
        head.addView(text("⌃", 20, RED, true));
        block.addView(head);
        block.addView(space(12));
        LinearLayout chips = row();
        for (String item : items) {
            chips.addView(tinyChip(item, false), new LinearLayout.LayoutParams(0, dp(42), 1));
            chips.addView(spaceW(8));
        }
        block.addView(chips);
        return block;
    }

    private View helpBox(String title, String body) {
        LinearLayout box = card();
        box.setGravity(Gravity.CENTER);
        box.setPadding(dp(10), dp(10), dp(10), dp(10));
        box.addView(helpIcon(title));
        box.addView(space(7));
        TextView t = text(title, 14, Color.BLACK, true);
        t.setGravity(Gravity.CENTER);
        box.addView(t);
        return box;
    }
    private TextView helpIcon(String title) {
        String icon = "?";
        if (title.contains("ใช้งาน")) icon = "☰";
        else if (title.contains("ราคา")) icon = "⚖";
        else if (title.contains("สั่งซื้อ")) icon = "🛒";
        else if (title.contains("ติดต่อ")) icon = "☎";
        TextView v = text(icon, 24, RED, true);
        v.setGravity(Gravity.CENTER);
        v.setBackground(stroke(SOFT, Color.rgb(246, 216, 224), 18));
        v.setLayoutParams(new LinearLayout.LayoutParams(dp(48), dp(48)));
        return v;
    }

    private View faq(String q) {
        LinearLayout f = row();
        f.setPadding(dp(14), 0, dp(14), 0);
        f.setBackground(stroke(Color.WHITE, LINE, 8));
        f.addView(text(q, 15, Color.BLACK, true), new LinearLayout.LayoutParams(0, -2, 1));
        f.addView(text("⌄", 18, Color.BLACK, true));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(48));
        lp.setMargins(0, 0, 0, dp(8));
        f.setLayoutParams(lp);
        return f;
    }

    private View topTitle(String label, boolean back) {
        LinearLayout row = row();
        if (back) row.addView(iconButton("‹", new View.OnClickListener() {
            @Override public void onClick(View v) { tab = 0; render(); }
        }));
        TextView title = text(label, 28, Color.BLACK, true);
        title.setGravity(back ? Gravity.CENTER : Gravity.LEFT);
        row.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        if (back) row.addView(iconButton("⌕", null));
        return row;
    }

    private void bottomNav() {
        if (nav == null) return;
        nav.removeAllViews();
        nav.addView(navItem("⌂", "หน้าแรก", 0), new LinearLayout.LayoutParams(0, -1, 1));
        nav.addView(navItem("⌕", "ค้นหา", 1), new LinearLayout.LayoutParams(0, -1, 1));
        nav.addView(navItem("▦", "หมวดหมู่", 2), new LinearLayout.LayoutParams(0, -1, 1));
        nav.addView(navItem("♡", "ถูกใจ", 3), new LinearLayout.LayoutParams(0, -1, 1));
        nav.addView(navItem("?", "ช่วยเหลือ", 4), new LinearLayout.LayoutParams(0, -1, 1));
    }

    private View navItem(String icon, String label, int target) {
        LinearLayout item = column();
        item.setGravity(Gravity.CENTER);
        TextView i = text(icon, 22, tab == target ? RED : Color.rgb(90, 95, 100), true);
        i.setGravity(Gravity.CENTER);
        TextView l = text(label, 11, tab == target ? RED : Color.rgb(90, 95, 100), tab == target);
        l.setGravity(Gravity.CENTER);
        item.addView(i);
        item.addView(l);
        item.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { tab = target; render(); }
        });
        return item;
    }

    private ImageButton iconButton(String label, View.OnClickListener listener) {
        ImageButton btn = new ImageButton(this);
        btn.setBackgroundColor(Color.TRANSPARENT);
        TextView fake = text(label, 22, Color.BLACK, true);
        btn.setContentDescription(label);
        if (listener != null) btn.setOnClickListener(listener);
        btn.setImageBitmap(textBitmap(label));
        return btn;
    }

    private TextView iconText(String label) {
        TextView v = text(label, 28, Color.BLACK, true);
        v.setGravity(Gravity.CENTER);
        return v;
    }

    private Bitmap textBitmap(String label) {
        TextView t = text(label, 26, Color.BLACK, true);
        t.setGravity(Gravity.CENTER);
        t.measure(View.MeasureSpec.makeMeasureSpec(dp(42), View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(dp(42), View.MeasureSpec.EXACTLY));
        t.layout(0, 0, dp(42), dp(42));
        Bitmap bitmap = Bitmap.createBitmap(dp(42), dp(42), Bitmap.Config.ARGB_8888);
        android.graphics.Canvas canvas = new android.graphics.Canvas(bitmap);
        t.draw(canvas);
        return bitmap;
    }

    private LinearLayout card() {
        LinearLayout card = column();
        card.setPadding(dp(12), dp(12), dp(12), dp(12));
        card.setBackground(stroke(Color.WHITE, LINE, 8));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.setMargins(0, 0, 0, dp(10));
        card.setLayoutParams(lp);
        return card;
    }

    private ImageView image(String link, int width, int height, ImageView.ScaleType scaleType) {
        ImageView img = new ImageView(this);
        img.setScaleType(scaleType);
        img.setBackgroundColor(Color.rgb(247, 247, 247));
        img.setAdjustViewBounds(false);
        img.setLayoutParams(new LinearLayout.LayoutParams(width, height));
        new Thread(new Runnable() {
            @Override public void run() {
                try {
                    Bitmap bitmap = BitmapFactory.decodeStream(new URL(link).openStream());
                    main.post(new Runnable() {
                        @Override public void run() { img.setImageBitmap(bitmap); }
                    });
                } catch (Exception ignored) {}
            }
        }).start();
        return img;
    }

    private View platformIcon(String key, int size) {
        FrameLayout box = new FrameLayout(this);
        box.setPadding(dp(size <= 26 ? 2 : 3), dp(size <= 26 ? 2 : 3), dp(size <= 26 ? 2 : 3), dp(size <= 26 ? 2 : 3));
        box.setBackground(stroke(Color.WHITE, LINE, 7));
        ImageView img = new ImageView(this);
        img.setScaleType(ImageView.ScaleType.FIT_CENTER);
        Bitmap bitmap = assetBitmap(platformAsset(key));
        if (bitmap != null) img.setImageBitmap(bitmap);
        box.addView(img, new FrameLayout.LayoutParams(-1, -1));
        box.setLayoutParams(new LinearLayout.LayoutParams(dp(size), dp(size)));
        return box;
    }

    private String platformAsset(String key) {
        if (key.contains("tiktok")) return "tiktok.png";
        if (key.contains("lazada")) return "lazada.png";
        if (key.contains("thai")) return "thaimart.png";
        return "shopee.jpg";
    }

    private Bitmap assetBitmap(String name) {
        try {
            InputStream in = getAssets().open(name);
            Bitmap bitmap = BitmapFactory.decodeStream(in);
            in.close();
            return bitmap;
        } catch (Exception ignored) {
            return null;
        }
    }

    private Button primaryButton(String label) {
        Button b = new Button(this);
        b.setAllCaps(false);
        b.setText(label);
        b.setTextColor(Color.WHITE);
        b.setTextSize(13);
        b.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        b.setBackground(round(RED, 8));
        return b;
    }

    private TextView text(String value, int sp, int color, boolean bold) {
        return text(value, sp, color, bold, 99);
    }

    private TextView text(String value, int sp, int color, boolean bold, int maxLines) {
        TextView t = new TextView(this);
        t.setText(value == null ? "" : value);
        t.setTextSize(sp);
        t.setTextColor(color);
        t.setIncludeFontPadding(true);
        if (bold) t.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        t.setMaxLines(maxLines);
        t.setEllipsize(android.text.TextUtils.TruncateAt.END);
        return t;
    }

    private LinearLayout column() {
        LinearLayout v = new LinearLayout(this);
        v.setOrientation(LinearLayout.VERTICAL);
        return v;
    }

    private LinearLayout row() {
        LinearLayout v = new LinearLayout(this);
        v.setOrientation(LinearLayout.HORIZONTAL);
        v.setGravity(Gravity.CENTER_VERTICAL);
        return v;
    }

    private View space(int h) {
        View v = new View(this);
        v.setLayoutParams(new LinearLayout.LayoutParams(1, dp(h)));
        return v;
    }

    private View spaceW(int w) {
        View v = new View(this);
        v.setLayoutParams(new LinearLayout.LayoutParams(dp(w), 1));
        return v;
    }

    private GradientDrawable round(int color, int radius) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(color);
        g.setCornerRadius(dp(radius));
        return g;
    }

    private GradientDrawable stroke(int color, int stroke, int radius) {
        GradientDrawable g = round(color, radius);
        g.setStroke(dp(1), stroke);
        return g;
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    private JSONObject fetchProductsBody() throws Exception {
        Exception lastError = null;
        for (String apiUrl : API_URLS) {
            try {
                return new JSONObject(get(apiUrl));
            } catch (Exception e) {
                lastError = e;
            }
        }
        throw lastError == null ? new Exception("API unavailable") : lastError;
    }

    private String get(String link) throws Exception {
        HttpURLConnection conn = null;
        BufferedReader reader = null;
        try {
            conn = (HttpURLConnection) new URL(link).openConnection();
            conn.setConnectTimeout(8000);
            conn.setReadTimeout(8000);
            int code = conn.getResponseCode();
            InputStream stream = code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream();
            if (stream == null) throw new Exception("HTTP " + code + " " + link);
            reader = new BufferedReader(new InputStreamReader(stream, "UTF-8"));
            StringBuilder out = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) out.append(line);
            if (code < 200 || code >= 300) throw new Exception("HTTP " + code + ": " + out);
            return out.toString();
        } finally {
            if (reader != null) reader.close();
            if (conn != null) conn.disconnect();
        }
    }

    private JSONObject bestOffer(JSONArray offers) {
        JSONArray sorted = sortedOffers(offers);
        return sorted.optJSONObject(0);
    }

    private JSONArray sortedOffers(JSONArray offers) {
        ArrayList<JSONObject> list = new ArrayList<>();
        if (offers != null) {
            for (int i = 0; i < offers.length(); i++) {
                JSONObject o = offers.optJSONObject(i);
                if (o != null && price(o) > 0) list.add(o);
            }
        }
        Collections.sort(list, new Comparator<JSONObject>() {
            @Override public int compare(JSONObject a, JSONObject b) {
                return Double.compare(price(a), price(b));
            }
        });
        JSONArray out = new JSONArray();
        for (JSONObject o : list) out.put(o);
        return out;
    }

    private double price(JSONObject offer) {
        if (offer == null) return 0;
        double p = offer.optDouble("effective_mobile_checkout_price", 0);
        if (p <= 0) p = offer.optDouble("total_payable", 0);
        return p;
    }

    private String baht(double amount) {
        if (Math.abs(amount - Math.round(amount)) < 0.005) {
            return "฿" + String.format(new Locale("th", "TH"), "%,.0f", amount);
        }
        return "฿" + String.format(new Locale("th", "TH"), "%,.2f", amount);
    }

    private String platform(JSONObject offer) {
        return offer == null ? "" : offer.optString("platform", "").toLowerCase();
    }

    private String platformLabel(String key) {
        if (key.contains("tiktok")) return "TikTok Shop";
        if (key.contains("shopee")) return "Shopee";
        if (key.contains("lazada")) return "Lazada";
        if (key.contains("thai")) return "Thai Mart";
        return "ร้านค้า";
    }

    private String link(JSONObject offer) {
        if (offer == null) return "";
        String url = offer.optString("affiliate_url", "");
        if (url.length() == 0) url = offer.optString("mobile_url", "");
        return url;
    }

    private int countPlatform() {
        int count = 0;
        for (JSONObject p : products) {
            JSONArray offers = p.optJSONArray("offers");
            if (offers != null) count += offers.length();
        }
        return count;
    }

    private void open(String link) {
        if (link == null || link.length() == 0) {
            Toast.makeText(this, "ยังไม่มีลิงก์", Toast.LENGTH_SHORT).show();
            return;
        }
        startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(link)));
    }

    private void loadFavorites() {
        favoriteIds.clear();
        SharedPreferences prefs = getSharedPreferences("np_market", MODE_PRIVATE);
        String raw = prefs.getString("favorites", "");
        if (raw == null || raw.length() == 0) return;
        String[] ids = raw.split(",");
        for (String id : ids) {
            if (id.trim().length() > 0 && favoriteIds.size() < 100) favoriteIds.add(id.trim());
        }
    }

    private void saveFavorites() {
        StringBuilder out = new StringBuilder();
        for (String id : favoriteIds) {
            if (out.length() > 0) out.append(",");
            out.append(id);
        }
        getSharedPreferences("np_market", MODE_PRIVATE).edit().putString("favorites", out.toString()).apply();
    }

    private boolean isFavorite(JSONObject product) {
        return favoriteIds.contains(product.optString("id"));
    }

    private void toggleFavorite(JSONObject product) {
        String id = product.optString("id");
        if (id.length() == 0) return;
        if (favoriteIds.contains(id)) {
            favoriteIds.remove(id);
            Toast.makeText(this, "เอาออกจากถูกใจแล้ว", Toast.LENGTH_SHORT).show();
        } else {
            if (favoriteIds.size() >= 100) favoriteIds.remove(favoriteIds.size() - 1);
            favoriteIds.add(0, id);
            Toast.makeText(this, "เพิ่มในถูกใจแล้ว", Toast.LENGTH_SHORT).show();
        }
        saveFavorites();
    }

    private ArrayList<JSONObject> favoriteProducts() {
        ArrayList<JSONObject> out = new ArrayList<>();
        for (String id : favoriteIds) {
            for (JSONObject p : products) {
                if (id.equals(p.optString("id"))) out.add(p);
            }
        }
        return out;
    }
}
