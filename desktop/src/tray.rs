use anyhow::Result;
use async_channel::Sender;
use tray_icon::{
    Icon, MouseButton, MouseButtonState, TrayIcon, TrayIconBuilder, TrayIconEvent,
    menu::{Menu, MenuEvent, MenuItem, PredefinedMenuItem},
};

pub enum Command {
    Toggle,
    Open,
    Settings,
    Quit,
}

pub struct Tray {
    icon: TrayIcon,
    open: MenuItem,
    settings: MenuItem,
    quit: MenuItem,
}

impl Tray {
    pub fn new(sender: Sender<Command>) -> Result<Self> {
        let menu = Menu::new();
        // Labels and tooltip are filled by `update`, which runs right after construction.
        let open = MenuItem::new("", true, None);
        let settings = MenuItem::new("", true, None);
        let quit = MenuItem::new("", true, None);
        menu.append_items(&[&open, &settings, &PredefinedMenuItem::separator(), &quit])?;
        let open_id = open.id().clone();
        let settings_id = settings.id().clone();
        let quit_id = quit.id().clone();
        let menu_sender = sender.clone();
        MenuEvent::set_event_handler(Some(move |event: MenuEvent| {
            let command = if event.id == open_id {
                Command::Open
            } else if event.id == settings_id {
                Command::Settings
            } else if event.id == quit_id {
                Command::Quit
            } else {
                return;
            };
            let _ = menu_sender.try_send(command);
        }));
        // macOS status items act on press, the same event that may blur the open popup, so
        // `toggle_panel` sees both from one press however long it is held. SNI only reports release.
        let toggle_on = if cfg!(target_os = "macos") {
            MouseButtonState::Down
        } else {
            MouseButtonState::Up
        };
        TrayIconEvent::set_event_handler(Some(move |event: TrayIconEvent| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state,
                ..
            } = event
                && button_state == toggle_on
            {
                let _ = sender.try_send(Command::Toggle);
            }
        }));
        // A small monochrome lightning silhouette; macOS tints the template for the menu bar.
        let mask = [
            ".........##.....",
            "........###.....",
            ".......####.....",
            "......####......",
            ".....#####......",
            "....#####.......",
            "...###########..",
            "..############..",
            ".......#####....",
            ".......####.....",
            "......####......",
            ".....####.......",
            ".....###........",
            "....###.........",
            "....##..........",
            "...#............",
        ];
        let rgba = mask
            .iter()
            .flat_map(|line| line.bytes())
            .flat_map(|pixel| {
                if pixel == b'#' {
                    if cfg!(target_os = "macos") {
                        [0, 0, 0, 255]
                    } else {
                        [232, 143, 45, 255]
                    }
                } else {
                    [0, 0, 0, 0]
                }
            })
            .collect();
        let image = Icon::from_rgba(rgba, 16, 16)?;
        #[cfg(target_os = "macos")]
        let builder = TrayIconBuilder::new().with_icon_templated(image);
        #[cfg(not(target_os = "macos"))]
        let builder = TrayIconBuilder::new().with_icon(image);
        let icon = builder
            .with_menu(Box::new(menu))
            .with_menu_on_left_click(false)
            .build()?;
        Ok(Self {
            icon,
            open,
            settings,
            quit,
        })
    }

    pub fn update(&self, power: &str, english: bool) {
        let (open, settings, quit, demo) = if english {
            ("Open panel", "Settings…", "Quit", "Demo")
        } else {
            ("打开面板", "设置…", "退出", "演示")
        };
        self.open.set_text(open);
        self.settings.set_text(settings);
        self.quit.set_text(quit);
        #[cfg(target_os = "macos")]
        self.icon.set_title(Some(format!("{demo} {power}")));
        if let Err(error) = self
            .icon
            .set_tooltip(Some(format!("CandySign · {demo} · {power}")))
        {
            eprintln!("prototype: cannot update tray tooltip: {error}");
        }
    }
}

#[cfg(target_os = "macos")]
pub fn popup_bounds(
    panel_size: gpui::Size<gpui::Pixels>,
    cx: &gpui::App,
) -> Option<gpui::Bounds<gpui::Pixels>> {
    use gpui::{Bounds, point, px};
    use objc2::MainThreadMarker;
    use objc2_app_kit::{NSEvent, NSScreen};

    // Read logical AppKit coordinates directly; avoid guessing a tray event's Retina scale.
    let main_thread = MainThreadMarker::new()?;
    let screens = NSScreen::screens(main_thread);
    let primary = screens.firstObject()?;
    let mouse = NSEvent::mouseLocation();
    let cursor = point(
        px(mouse.x as f32),
        px((primary.frame().size.height - mouse.y) as f32),
    );
    let display = cx
        .displays()
        .into_iter()
        .find(|display| display.bounds().contains(&cursor))?;
    let visible = display.visible_bounds();
    let width = panel_size.width.min(visible.size.width - px(8.));
    let height = panel_size.height.min(visible.size.height - px(8.));
    let x =
        (cursor.x - width / 2.).clamp(visible.left() + px(4.), visible.right() - width - px(4.));
    let y = (cursor.y + px(12.)).clamp(visible.top() + px(4.), visible.bottom() - height - px(4.));
    Some(Bounds::new(point(x, y), gpui::size(width, height)))
}
