//! La scène 2D du viseur, avec le moteur `paquets::ecs` : des grains d'argent qui
//! montent en ondulant, et un éclat de particules à chaque toucher.
//! Le canvas est transparent : le dégradé de l'écran, en CSS, passe derrière.

use paquets::ecs::prelude::*;
use wasm_bindgen::JsCast;

/// Les couleurs de FLASHA : bleu cyanotype, halo orange, encre, et un bleu vif.
const PALETTE: [(u8, u8, u8); 4] = [(29, 63, 209), (255, 91, 46), (21, 19, 15), (46, 91, 255)];

/// Une bulle qui monte : vitesse (px/s), amplitude et phase de l'ondulation.
struct Bubble {
    speed: f32,
    sway: f32,
    phase: f32,
    base_x: f32,
}
paquets::active::component!(Bubble);

/// Une particule de flash : vitesse, durée de vie restante et totale.
struct Spark {
    velocity: Vec2,
    life: f32,
    total: f32,
}
paquets::active::component!(Spark);

/// Le matériau de chaque forme, pour changer sa transparence.
struct Tint(Handle<ColorMaterial>, f32);
paquets::active::component!(Tint);

/// Un générateur pseudo-aléatoire, pour ne dépendre d'aucune crate.
struct Rng(u32);
paquets::active::resource!(Rng);

impl Rng {
    fn next(&mut self) -> f32 {
        // xorshift32
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.0 = x;
        (x as f32) / (u32::MAX as f32)
    }

    fn range(&mut self, min: f32, max: f32) -> f32 {
        min + (max - min) * self.next()
    }
}

/// Le mouvement est réduit : les bulles restent presque immobiles.
struct Calm(bool);
paquets::active::resource!(Calm);

/// Les bulles sont créées une fois la taille de l'écran connue.
#[derive(Default)]
struct Started(bool);
paquets::active::resource!(Started);

fn color(rgb: (u8, u8, u8), alpha: f32) -> Color {
    Color::srgba(
        f32::from(rgb.0) / 255.0,
        f32::from(rgb.1) / 255.0,
        f32::from(rgb.2) / 255.0,
        alpha,
    )
}

fn setup(mut commands: Commands) {
    commands.spawn((
        Camera2d,
        Camera {
            clear_color: ClearColorConfig::None,
            ..Camera::default()
        },
    ));
}

/// Les bulles, réparties sur toute la hauteur de l'écran.
fn bubbles(
    mut commands: Commands,
    mut started: ResMut<Started>,
    mut rng: ResMut<Rng>,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
    window: Single<&Window>,
) {
    let (w, h) = (window.width(), window.height());
    if started.0 || w < 2.0 || h < 2.0 {
        return;
    }
    started.0 = true;
    let count = ((w * h) / 4200.0).clamp(14.0, 40.0) as usize;
    for i in 0..count {
        let radius = rng.range(3.0, 16.0);
        let alpha = rng.range(0.25, 0.7);
        let material = materials.add(ColorMaterial::from(color(
            PALETTE[i % PALETTE.len()],
            alpha,
        )));
        let x = rng.range(-w / 2.0, w / 2.0);
        commands.spawn((
            Mesh2d(meshes.add(Circle::new(radius))),
            MeshMaterial2d(material),
            Transform::from_xyz(x, rng.range(-h / 2.0, h / 2.0), radius),
            Bubble {
                speed: rng.range(14.0, 46.0) * (12.0 / radius).sqrt(),
                sway: rng.range(4.0, 18.0),
                phase: rng.range(0.0, std::f32::consts::TAU),
                base_x: x,
            },
            Tint(material, alpha),
        ));
    }
}

/// Elles montent en ondulant, et reviennent par le bas.
fn rise(
    time: Res<Time>,
    calm: Res<Calm>,
    window: Single<&Window>,
    mut query: Query<(&mut Transform, &mut Bubble)>,
) {
    let (w, h) = (window.width(), window.height());
    let dt = time.delta_secs().min(0.05) * if calm.0 { 0.08 } else { 1.0 };
    let t = time.elapsed_secs();
    for (mut transform, mut bubble) in &mut query {
        transform.translation.y += bubble.speed * dt;
        if transform.translation.y > h / 2.0 + 20.0 {
            transform.translation.y = -h / 2.0 - 20.0;
            bubble.base_x = bubble.base_x.clamp(-w / 2.0, w / 2.0);
        }
        transform.translation.x = bubble.base_x + (t * 0.8 + bubble.phase).sin() * bubble.sway;
    }
}

/// Un toucher : un éclat de particules aux couleurs de FLASHA.
fn burst(
    mut commands: Commands,
    buttons: Res<ButtonInput<MouseButton>>,
    window: Single<&Window>,
    mut rng: ResMut<Rng>,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
) {
    if !buttons.just_pressed(MouseButton::Left) {
        return;
    }
    let Some(at) = window.cursor_position() else {
        return;
    };
    let origin = Vec2::new(at.x - window.width() / 2.0, window.height() / 2.0 - at.y);
    for i in 0..28 {
        let angle = (i as f32 / 28.0) * std::f32::consts::TAU + rng.range(-0.1, 0.1);
        let speed = rng.range(90.0, 260.0);
        let total = rng.range(0.6, 1.1);
        let material = materials.add(ColorMaterial::from(color(PALETTE[i % PALETTE.len()], 1.0)));
        let size = rng.range(3.0, 7.0);
        commands.spawn((
            Mesh2d(meshes.add(Circle::new(size))),
            MeshMaterial2d(material),
            Transform::from_xyz(origin.x, origin.y, 50.0),
            Spark {
                velocity: Vec2::new(angle.cos(), angle.sin()) * speed,
                life: total,
                total,
            },
            Tint(material, 1.0),
        ));
    }
}

/// Les particules ralentissent, tombent un peu, pâlissent puis disparaissent.
fn sparks(
    mut commands: Commands,
    time: Res<Time>,
    mut materials: ResMut<Assets<ColorMaterial>>,
    mut query: Query<(Entity, &mut Transform, &mut Spark, &Tint)>,
) {
    let dt = time.delta_secs().min(0.05);
    for (entity, mut transform, mut spark, tint) in &mut query {
        spark.life -= dt;
        if spark.life <= 0.0 {
            commands.entity(entity).despawn();
            continue;
        }
        spark.velocity = spark.velocity * (1.0 - 2.2 * dt);
        spark.velocity.y -= 160.0 * dt;
        transform.translation.x += spark.velocity.x * dt;
        transform.translation.y += spark.velocity.y * dt;
        let left = spark.life / spark.total;
        transform.scale = Vec3::splat(0.4 + 0.6 * left);
        if let Some(material) = materials.get_mut(tint.0) {
            material.color = material.color.with_alpha(tint.1 * left);
        }
    }
}

fn reduced_motion() -> bool {
    web_sys::window()
        .and_then(|w| {
            w.match_media("(prefers-reduced-motion: reduce)")
                .ok()
                .flatten()
        })
        .is_some_and(|m| m.matches())
}

/// Lance la scène dans le canvas ; elle s'arrête quand la valeur rendue est lâchée.
pub fn start(canvas: &web_sys::Element) -> Option<Running> {
    let seed = (js_now() as u32) | 1;
    let mut app = App::new();
    app.add_plugins(DefaultPlugins)
        .insert_resource(Rng(seed))
        .insert_resource(Calm(reduced_motion()))
        .init_resource::<Started>()
        .add_systems(Startup, setup)
        .add_systems(Update, (bubbles, rise, burst, sparks));
    let running = match app.run_in(canvas) {
        Ok(running) => running,
        Err(error) => {
            web_sys::console::warn_1(&error.into());
            return None;
        }
    };
    // La page doit continuer à défiler au doigt par-dessus l'écran.
    if let Some(el) = canvas.dyn_ref::<web_sys::HtmlElement>() {
        let _ = el.style().set_property("touch-action", "pan-y");
    }
    Some(running)
}

fn js_now() -> f64 {
    js_sys_now()
}

#[wasm_bindgen::prelude::wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = Date, js_name = now)]
    fn js_sys_now() -> f64;
}
