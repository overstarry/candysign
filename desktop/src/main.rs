extern crate gpui_kit as gpui;

mod tray;
mod ui;

use gpui_kit::component::ThemeMode;
use gpui_kit::*;
use std::time::{Duration, Instant};
use tray::{Command, Tray};

actions!(
    candysign,
    [Quit, OpenPanel, OpenSettings, RefreshDemo, CloseWindow]
);

#[derive(Clone, Copy, PartialEq, Eq)]
enum DemoStatus {
    Sample,
    Stale,
    Offline,
}

struct Desktop {
    tray: Option<Tray>,
    /// The panel window, and whether it is the transient popup.
    panel: Option<(AnyWindowHandle, bool)>,
    settings: Option<AnyWindowHandle>,
    window_mode: bool,
    last_dismissed: Option<Instant>,
    language: Option<bool>,
    system_english: bool,
    appearance: Option<ThemeMode>,
    status: DemoStatus,
    alternate_sample: bool,
    selected_port: Option<usize>,
}

impl Desktop {
    fn is_english(&self) -> bool {
        self.language.unwrap_or(self.system_english)
    }

    fn text(&self, zh: &'static str, en: &'static str) -> &'static str {
        if self.is_english() { en } else { zh }
    }

    fn settings_title(&self) -> &'static str {
        self.text("CandySign · 原型设置", "CandySign · Prototype settings")
    }

    fn watts(&self, port: usize) -> f64 {
        match port {
            1 if self.alternate_sample => 61.8,
            1 => 65.2,
            2 => 18.4,
            _ => 0.,
        }
    }

    fn total_watts(&self) -> f64 {
        (0..5).map(|port| self.watts(port)).sum()
    }

    fn notify_status(&mut self, cx: &mut Context<Self>) {
        if let Some(tray) = &self.tray {
            let power = if self.status == DemoStatus::Sample {
                format!("{:.1} W", self.total_watts())
            } else {
                "— W".into()
            };
            tray.update(&power, self.is_english());
        }
        cx.notify();
    }

    fn refresh_demo(&mut self, cx: &mut Context<Self>) {
        self.alternate_sample = !self.alternate_sample;
        self.status = DemoStatus::Sample;
        self.notify_status(cx);
    }

    /// A status-item click dismisses the popup; otherwise it opens or raises the panel.
    fn toggle_panel(desktop: &Entity<Self>, cx: &mut App) -> anyhow::Result<()> {
        if let Some((panel, true)) = desktop.read(cx).panel
            && cx.windows().contains(&panel)
        {
            cx.defer(move |cx| {
                let _ = panel.update(cx, |_, window, _| window.remove_window());
            });
            return Ok(());
        }
        // The same press may have just blurred the popup; it must not reopen it. Both come
        // from one mouse-down, so this window only covers their dispatch order.
        if desktop
            .read(cx)
            .last_dismissed
            .is_some_and(|at| at.elapsed() < Duration::from_millis(250))
        {
            return Ok(());
        }
        Self::show_panel(desktop, true, cx)
    }

    fn show_panel(desktop: &Entity<Self>, from_tray: bool, cx: &mut App) -> anyhow::Result<()> {
        if let Some((panel, _)) = desktop.read(cx).panel
            && cx.windows().contains(&panel)
        {
            // Actions can arrive while this very window is leased by the event dispatcher.
            cx.defer(move |cx| {
                let _ = panel.update(cx, |_, window, _| window.activate_window());
                cx.activate(true);
            });
            return Ok(());
        }
        let popup = from_tray && !desktop.read(cx).window_mode;
        let panel_size = size(px(400.), px(560.));
        let bounds = Bounds::centered(None, panel_size, cx);
        #[cfg(target_os = "macos")]
        let bounds = if popup {
            tray::popup_bounds(panel_size, cx).unwrap_or(bounds)
        } else {
            bounds
        };
        let state = desktop.clone();
        let (panel, _) = gpui_kit::open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                titlebar: (!popup).then(|| TitlebarOptions {
                    title: Some("CandySign · GPUI Kit Prototype".into()),
                    ..Default::default()
                }),
                kind: if popup {
                    WindowKind::PopUp
                } else {
                    WindowKind::Normal
                },
                is_resizable: !popup,
                window_min_size: Some(size(px(380.), px(460.))),
                app_id: Some("com.candysign.desktop.prototype".into()),
                ..Default::default()
            },
            cx,
            |window, cx| cx.new(|cx| ui::Panel::new(state, popup, window, cx)),
        )?;
        desktop.update(cx, |desktop, _| desktop.panel = Some((panel, popup)));
        cx.activate(true);
        eprintln!("prototype: panel opened (popup={popup})");
        Ok(())
    }

    fn show_settings(desktop: &Entity<Self>, cx: &mut App) -> anyhow::Result<()> {
        if let Some(settings) = desktop.read(cx).settings
            && cx.windows().contains(&settings)
        {
            cx.defer(move |cx| {
                let _ = settings.update(cx, |_, window, _| window.activate_window());
                cx.activate(true);
            });
            return Ok(());
        }
        let title = desktop.read(cx).settings_title();
        let state = desktop.clone();
        let (settings, _) = gpui_kit::open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(Bounds::centered(
                    None,
                    size(px(480.), px(450.)),
                    cx,
                ))),
                titlebar: Some(TitlebarOptions {
                    title: Some(title.into()),
                    ..Default::default()
                }),
                window_min_size: Some(size(px(460.), px(420.))),
                app_id: Some("com.candysign.desktop.prototype".into()),
                ..Default::default()
            },
            cx,
            |window, cx| cx.new(|cx| ui::Settings::new(state, window, cx)),
        )?;
        desktop.update(cx, |desktop, _| desktop.settings = Some(settings));
        cx.activate(true);
        eprintln!("prototype: settings opened");
        Ok(())
    }
}

fn main() -> anyhow::Result<()> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--help" || arg == "-h") {
        println!(
            "CandySign GPUI Kit prototype (demo data only)\n\n--window   Keep a normal window instead of a transient macOS panel\n--no-tray  Run without a tray icon; closing the last window quits"
        );
        return Ok(());
    }
    for arg in &args {
        anyhow::ensure!(
            matches!(arg.as_str(), "--window" | "--no-tray"),
            "Unknown option: {arg}"
        );
    }
    let no_tray = args.iter().any(|arg| arg == "--no-tray");
    // Windows/Linux start with a normal, taskbar-accessible window, including desktops without SNI.
    let window_mode =
        !cfg!(target_os = "macos") || no_tray || args.iter().any(|arg| arg == "--window");

    let app = gpui_kit::application()
        .with_assets(gpui_kit::assets::Assets)
        .with_quit_mode(QuitMode::Explicit);
    // macOS Dock icon click, e.g. with `--window` after its panel was closed.
    app.on_reopen(|cx| cx.dispatch_action(&OpenPanel));
    app.run(move |cx| {
        gpui_kit::init(cx);
        let (sender, receiver) = async_channel::unbounded();
        let tray = if no_tray {
            None
        } else {
            match Tray::new(sender) {
                Ok(tray) => Some(tray),
                Err(error) => {
                    eprintln!("prototype: tray unavailable, using a normal window: {error}");
                    None
                }
            }
        };
        let has_tray = tray.is_some();
        #[cfg(target_os = "macos")]
        if has_tray && !window_mode {
            cx.set_activation_policy(ActivationPolicy::Accessory);
        }
        let desktop = cx.new(|_| Desktop {
            tray,
            panel: None,
            settings: None,
            window_mode: window_mode || !has_tray,
            last_dismissed: None,
            language: None,
            system_english: !sys_locale::get_locale()
                .unwrap_or_default()
                .to_ascii_lowercase()
                .starts_with("zh"),
            appearance: None,
            status: DemoStatus::Sample,
            alternate_sample: false,
            selected_port: None,
        });
        desktop.update(cx, |desktop, cx| desktop.notify_status(cx));
        if let Err(error) = Desktop::show_panel(&desktop, false, cx) {
            eprintln!("prototype: cannot open panel: {error}");
            cx.quit();
        }

        #[cfg(target_os = "macos")]
        let (quit_key, settings_key, refresh_key) = ("cmd-q", "cmd-,", "cmd-r");
        #[cfg(not(target_os = "macos"))]
        let (quit_key, settings_key, refresh_key) = ("ctrl-q", "ctrl-,", "ctrl-r");
        cx.bind_keys([
            KeyBinding::new(quit_key, Quit, None),
            KeyBinding::new(settings_key, OpenSettings, None),
            KeyBinding::new(refresh_key, RefreshDemo, None),
            KeyBinding::new("escape", CloseWindow, None),
        ]);
        cx.on_action(|_: &Quit, cx| cx.quit());
        let settings_desktop = desktop.clone();
        cx.on_action(move |_: &OpenSettings, cx| {
            if let Err(error) = Desktop::show_settings(&settings_desktop, cx) {
                eprintln!("prototype: cannot open settings: {error}");
            }
        });
        let refresh_desktop = desktop.clone();
        cx.on_action(move |_: &RefreshDemo, cx| {
            refresh_desktop.update(cx, |desktop, cx| desktop.refresh_demo(cx));
        });
        let panel_desktop = desktop.clone();
        cx.on_action(move |_: &OpenPanel, cx| {
            if let Err(error) = Desktop::show_panel(&panel_desktop, false, cx) {
                eprintln!("prototype: cannot open panel: {error}");
            }
        });
        // Linux can successfully register an SNI service without any tray host being present.
        // Keep an ordinary window as its reliable entry point; closing its last window exits.
        if !has_tray || cfg!(target_os = "linux") {
            cx.on_window_closed(|cx, _| {
                if cx.windows().is_empty() {
                    cx.quit();
                }
            })
            .detach();
        }
        cx.spawn(async move |cx| {
            while let Ok(command) = receiver.recv().await {
                cx.update(|cx| {
                    let result = match command {
                        Command::Toggle => Desktop::toggle_panel(&desktop, cx),
                        Command::Open => Desktop::show_panel(&desktop, true, cx),
                        Command::Settings => Desktop::show_settings(&desktop, cx),
                        Command::Quit => {
                            cx.quit();
                            Ok(())
                        }
                    };
                    if let Err(error) = result {
                        eprintln!("prototype: {error}");
                    }
                });
            }
        })
        .detach();
    });
    eprintln!("prototype: exited normally");
    Ok(())
}
