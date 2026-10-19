//! The VIDORA wordmark (Imal Madhusanka's logo for VIDORA), decoded once and kept as a texture.
//!
//! FilmCraft drew the ArtCraft wordmark here. VIDORA is a modified version of FilmCraft, so under
//! the ArtCraft brand licence it carries its own marks instead. Until the VIDORA wordmark is
//! added (`LOGO_LIGHT_INK` / `LOGO_DARK_INK`), nothing is drawn and callers fall back to text.

/// The wordmark for dark themes (light ink), as a PNG, when the build has one.
const LOGO_LIGHT_INK: Option<&[u8]> = None;
/// The wordmark for light themes (dark ink), as a PNG, when the build has one.
const LOGO_DARK_INK: Option<&[u8]> = None;

/// Whether this build has a wordmark to draw.
pub fn has_wordmark() -> bool {
    LOGO_LIGHT_INK.is_some() && LOGO_DARK_INK.is_some()
}

/// The wordmark for a dark (`dark = true`) or light UI: light ink on dark themes. Its aspect
/// ratio is width / height of the returned texture.
pub fn wordmark(ctx: &egui::Context, dark: bool) -> Option<egui::TextureHandle> {
    let id = egui::Id::new(("vidora-wordmark", dark));
    if let Some(t) = ctx.data(|d| d.get_temp::<egui::TextureHandle>(id)) {
        return Some(t);
    }
    let bytes = if dark { LOGO_LIGHT_INK } else { LOGO_DARK_INK }?;
    let img = image::load_from_memory_with_format(bytes, image::ImageFormat::Png).ok()?;
    // Large enough to stay sharp at 2x for the sizes we draw (≤ 320 pt wide).
    let img = img.resize(1024, 1024, image::imageops::FilterType::Lanczos3).to_rgba8();
    let color = egui::ColorImage::from_rgba_unmultiplied([img.width() as usize, img.height() as usize], img.as_raw());
    let tex = ctx.load_texture("vidora-wordmark", color, egui::TextureOptions::LINEAR);
    ctx.data_mut(|d| d.insert_temp(id, tex.clone()));
    Some(tex)
}

/// Draw the wordmark `height` points tall with its left edge at `left_center` (vertically centred).
/// Returns the drawn rect, or `None` when the build has no wordmark.
pub fn paint_wordmark(ui: &egui::Ui, left_center: egui::Pos2, height: f32, dark: bool) -> Option<egui::Rect> {
    let tex = wordmark(ui.ctx(), dark)?;
    let [w, h] = tex.size();
    let width = height * w as f32 / h.max(1) as f32;
    let r = egui::Rect::from_min_size(egui::pos2(left_center.x, left_center.y - height / 2.0), egui::vec2(width, height));
    ui.painter().image(tex.id(), r, egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)), egui::Color32::WHITE);
    Some(r)
}
