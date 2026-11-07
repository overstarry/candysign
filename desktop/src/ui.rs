// Operate: extend CandySign's compact native panel, not a new dashboard identity.
// Demo values are always labeled; this prototype never connects to a charger.
use crate::{CloseWindow, DemoStatus, Desktop};
use gpui_kit::component::{
    ActiveTheme, ElementExt, Icon, IconName, Selectable, Sizable, StyledExt, Theme, ThemeMode,
    button::{Button, ButtonGroup, ButtonVariants},
    chart::LineChart,
    progress::Progress,
    scroll::ScrollableElement,
};
use gpui_kit::prelude::FluentBuilder;
use gpui_kit::*;
use std::time::Instant;

/// Follow the OS appearance unless one was picked. Sync on open too: changes made while no
/// window was open had no observer.
fn follow_system_appearance<V: 'static>(
    desktop: &Entity<Desktop>,
    window: &mut Window,
    cx: &mut Context<V>,
) -> Subscription {
    let desktop = desktop.clone();
    let sync = move |window: &mut Window, cx: &mut App| {
        if desktop.read(cx).appearance.is_none() {
            Theme::sync_system_appearance(Some(window), cx);
        }
    };
    sync(window, cx);
    cx.observe_window_appearance(window, move |_, window, cx| sync(window, cx))
}

pub struct Panel {
    desktop: Entity<Desktop>,
    focus: FocusHandle,
    popup: bool,
    scroll_viewport_height: Pixels,
    _subscriptions: Vec<Subscription>,
}

impl Panel {
    pub fn new(
        desktop: Entity<Desktop>,
        popup: bool,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Self {
        let focus = cx.focus_handle();
        window.focus(&focus, cx);
        let mut subscriptions = vec![cx.observe(&desktop, |_, _, cx| cx.notify())];
        if popup {
            let state = desktop.clone();
            subscriptions.push(cx.observe_window_activation(window, move |_, window, cx| {
                if !window.is_window_active() {
                    state.update(cx, |desktop, _| {
                        desktop.last_dismissed = Some(Instant::now())
                    });
                    window.remove_window();
                    eprintln!("prototype: popup dismissed on blur");
                }
            }));
        }
        subscriptions.push(follow_system_appearance(&desktop, window, cx));
        Self {
            desktop,
            focus,
            popup,
            scroll_viewport_height: px(0.),
            _subscriptions: subscriptions,
        }
    }

    /// Size the popup so its scroll area fits the content, capped at the screen bottom. The
    /// rest of the window (header, footer, padding, gaps) is whatever the scroll area isn't.
    fn fit_popup(&self, content_height: Pixels, window: &mut Window, cx: &mut App) {
        let natural = window.viewport_size().height - self.scroll_viewport_height + content_height;
        let available = window
            .display(cx)
            .map(|display| display.visible_bounds().bottom() - window.bounds().top() - px(4.))
            .unwrap_or(natural);
        let height = natural.min(available);
        if (window.viewport_size().height - height).abs() > px(1.) {
            window.defer(cx, move |window, _| {
                window.resize(size(window.viewport_size().width, height));
            });
        }
    }
}

impl Render for Panel {
    fn render(&mut self, _: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let desktop = self.desktop.read(cx);
        let text = |zh, en| desktop.text(zh, en);
        let foreground = cx.theme().foreground;
        let muted = cx.theme().muted_foreground;
        let border = cx.theme().border;
        let accent = gpui_kit::component::ColorName::Orange.scale(if cx.theme().is_dark() {
            400
        } else {
            600
        });
        let status = match desktop.status {
            DemoStatus::Sample => text("演示数据", "Demo data"),
            DemoStatus::Stale => text("演示 · 已过期", "Demo · Stale"),
            DemoStatus::Offline => text("演示 · 离线", "Demo · Offline"),
        };
        let total = desktop.total_watts();
        let selected = desktop.selected_port;
        let retained = desktop.status != DemoStatus::Sample;
        let tnum = FontFeatures(vec![("tnum".into(), 1)].into());
        let panel = cx.entity().downgrade();
        let mut ports = div().v_flex();
        for (index, name) in ["A", "C1", "C2", "C3", "C4"].into_iter().enumerate() {
            let watts = desktop.watts(index);
            let connected = (1..=3).contains(&index);
            let charging = (1..=2).contains(&index);
            let device = match index {
                1 => "MacBook Pro",
                2 => "iPhone",
                3 => text("已连接设备", "Connected device"),
                _ => text("未连接", "Disconnected"),
            };
            let state = if charging {
                text("充电中", "Charging")
            } else if connected {
                text("已连接 · 未充电", "Connected · Not charging")
            } else {
                text("端口空闲", "Port idle")
            };
            let mut row = div().v_flex().border_b_1().border_color(border).child(
                Button::new(("port", index))
                    .ghost()
                    .w_full()
                    .h(px(54.))
                    .px_1()
                    .accessibility_label(format!("{name}, {device}, {state}, {watts:.1} W"))
                    .child(
                        div()
                            .h_flex()
                            .w_full()
                            .gap_3()
                            .child(div().w_6().font_weight(FontWeight::SEMIBOLD).child(name))
                            .child(
                                div()
                                    .v_flex()
                                    .flex_1()
                                    .min_w_0()
                                    .items_start()
                                    .gap_1()
                                    .child(div().text_sm().child(device))
                                    .child(div().text_xs().text_color(muted).child(state)),
                            )
                            .child(
                                div()
                                    .font_features(tnum.clone())
                                    .font_weight(FontWeight::SEMIBOLD)
                                    .child(format!("{watts:.1} W")),
                            )
                            .child(
                                Icon::new(if selected == Some(index) {
                                    IconName::ChevronDown
                                } else {
                                    IconName::ChevronRight
                                })
                                .xsmall()
                                .text_color(muted),
                            ),
                    )
                    .on_click(cx.listener(move |this, _, _, cx| {
                        this.desktop.update(cx, |desktop, cx| {
                            desktop.selected_port = if desktop.selected_port == Some(index) {
                                None
                            } else {
                                Some(index)
                            };
                            cx.notify();
                        });
                    })),
            );
            if selected == Some(index) {
                let readings: Vec<_> = [0.78, 0.84, 0.91, 0.87, 0.96, 0.94, 1.0]
                    .into_iter()
                    .enumerate()
                    .map(|(i, factor)| (i.to_string(), watts * factor))
                    .collect();
                row = row.child(
                    div()
                        .v_flex()
                        .pl_10()
                        .pb_3()
                        .gap_2()
                        .child(
                            div()
                                .h_flex()
                                .justify_between()
                                .text_xs()
                                .text_color(muted)
                                .font_features(tnum.clone())
                                .child(if charging {
                                    format!(
                                        "{} V · {:.2} A · PD",
                                        if index == 1 { "20.0" } else { "9.0" },
                                        watts / if index == 1 { 20. } else { 9. }
                                    )
                                } else {
                                    "— V · — A".into()
                                })
                                .child(if index == 1 { "0–100 W" } else { "0–30 W" }),
                        )
                        .child(
                            div().h(px(76.)).w_full().child(
                                LineChart::new(readings)
                                    .id(("history", index))
                                    .x(|sample| sample.0.clone())
                                    .y(|sample| sample.1)
                                    .linear()
                                    .stroke(accent)
                                    .y_domain(0., if index == 1 { 100. } else { 30. })
                                    .x_axis(false)
                                    .y_axis(false)
                                    .grid(false)
                                    .appear(false)
                                    .interactive(false),
                            ),
                        )
                        .child(
                            div()
                                .h_flex()
                                .justify_between()
                                .text_xs()
                                .text_color(muted)
                                .child(text("样本 1 → 7", "Samples 1 → 7"))
                                .child(text("合成演示 · 非真实历史", "Synthetic · Not history")),
                        ),
                );
            }
            ports = ports.child(row);
        }
        div()
            .v_flex()
            .size_full()
            .p_4()
            .gap_3()
            .track_focus(&self.focus)
            .bg(cx.theme().background)
            .text_color(foreground)
            .text_sm()
            .on_action(|_: &CloseWindow, window, _| window.remove_window())
            .child(
                div()
                    .h_flex()
                    .flex_shrink_0()
                    .gap_3()
                    .child(
                        Icon::new(gpui_kit::assets::IconName::BatteryCharging)
                            .text_color(accent)
                            .size_6(),
                    )
                    .child(
                        div()
                            .v_flex()
                            .flex_1()
                            .gap_1()
                            .child(
                                div()
                                    .font_weight(FontWeight::SEMIBOLD)
                                    .child(text("小电拼 2838", "CoCan 2838")),
                            )
                            .child(
                                div()
                                    .text_xs()
                                    .text_color(muted)
                                    .child("CandySign · GPUI Kit"),
                            ),
                    )
                    .child(div().text_xs().child(status)),
            )
            .child(
                div()
                    .id("panel-content")
                    .flex_1()
                    .min_h_0()
                    // The viewport's own canvas is its first child, so it is measured before the content.
                    .when(self.popup, |this| {
                        let panel = panel.clone();
                        this.on_prepaint(move |bounds, _, cx| {
                            let _ = panel.update(cx, |panel, _| {
                                panel.scroll_viewport_height = bounds.size.height
                            });
                        })
                    })
                    .overflow_y_scrollbar()
                    .child(
                        div()
                            .v_flex()
                            .gap_3()
                            .pr_3()
                            .when(self.popup, |this| {
                                this.on_prepaint(move |bounds, window, cx| {
                                    let _ = panel.update(cx, |panel, cx| {
                                        panel.fit_popup(bounds.size.height, window, cx)
                                    });
                                })
                            })
                            .child(
                                div()
                                    .v_flex()
                                    .py_2()
                                    .gap_2()
                                    .child(
                                        div()
                                            .h_flex()
                                            .items_baseline()
                                            .justify_between()
                                            .child(
                                                div()
                                                    .h_flex()
                                                    .items_baseline()
                                                    .gap_1()
                                                    .font_features(tnum)
                                                    .child(
                                                        div()
                                                            .text_3xl()
                                                            .font_weight(FontWeight::SEMIBOLD)
                                                            .child(format!("{total:.1}")),
                                                    )
                                                    .child(
                                                        div()
                                                            .text_lg()
                                                            .text_color(muted)
                                                            .child("W"),
                                                    ),
                                            )
                                            .child(
                                                div()
                                                    .text_xs()
                                                    .when(!retained, |this| this.text_color(muted))
                                                    .child(if retained {
                                                        text(
                                                            "上次读数 · 非实时",
                                                            "Last reading · Not live",
                                                        )
                                                    } else {
                                                        text("2 个端口充电中", "2 ports charging")
                                                    }),
                                            ),
                                    )
                                    .child(
                                        Progress::new("power")
                                            .value((total / 160. * 100.) as f32)
                                            .color(accent)
                                            .xsmall()
                                            .accessibility_label(text(
                                                "演示输出相对于额定容量",
                                                "Demo output relative to rated capacity",
                                            )),
                                    )
                                    .child(
                                        div()
                                            .h_flex()
                                            .justify_between()
                                            .text_xs()
                                            .text_color(muted)
                                            .child(text("额定总功率 160 W", "160 W total capacity"))
                                            .when(retained, |this| {
                                                this.child(text(
                                                    "2 个端口曾充电",
                                                    "2 ports were charging",
                                                ))
                                            }),
                                    ),
                            )
                            .when(desktop.status != DemoStatus::Sample, |this| {
                                this.child(div().text_sm().child(
                                    if desktop.status == DemoStatus::Offline {
                                        text(
                                            "模拟离线，保留上次读数。",
                                            "Simulated offline. Last readings retained.",
                                        )
                                    } else {
                                        text(
                                            "模拟数据过期，保留上次读数。",
                                            "Simulated stale data. Last readings retained.",
                                        )
                                    },
                                ))
                            })
                            .child(ports)
                            .child(
                                div()
                                    .h_flex()
                                    .justify_between()
                                    .text_xs()
                                    .text_color(muted)
                                    .child(text("温控优先 · 示例", "Temperature priority · Demo"))
                                    .child("CP-02S"),
                            ),
                    ),
            )
            .child(
                div()
                    .h_flex()
                    .flex_shrink_0()
                    .gap_1()
                    .pt_2()
                    .border_t_1()
                    .border_color(border)
                    .child(
                        Button::new("refresh-demo")
                            .ghost()
                            .small()
                            .icon(IconName::RotateCw)
                            .label(text("刷新演示", "Refresh demo"))
                            .on_click(cx.listener(|this, _, _, cx| {
                                this.desktop
                                    .update(cx, |desktop, cx| desktop.refresh_demo(cx))
                            })),
                    )
                    .child(div().flex_1())
                    .child(
                        Button::new("settings")
                            .ghost()
                            .small()
                            .icon(IconName::Settings)
                            .label(text("设置", "Settings"))
                            .on_click(cx.listener(|this, _, _, cx| {
                                if let Err(error) = Desktop::show_settings(&this.desktop, cx) {
                                    eprintln!("prototype: {error}");
                                }
                            })),
                    )
                    .child(
                        Button::new("quit")
                            .ghost()
                            .small()
                            .label(text("退出", "Quit"))
                            .on_click(|_, _, cx| cx.quit()),
                    ),
            )
    }
}

pub struct Settings {
    desktop: Entity<Desktop>,
    focus: FocusHandle,
    _subscriptions: Vec<Subscription>,
}

impl Settings {
    pub fn new(desktop: Entity<Desktop>, window: &mut Window, cx: &mut Context<Self>) -> Self {
        let focus = cx.focus_handle();
        window.focus(&focus, cx);
        let subscriptions = vec![
            cx.observe(&desktop, |_, _, cx| cx.notify()),
            follow_system_appearance(&desktop, window, cx),
        ];
        Self {
            desktop,
            focus,
            _subscriptions: subscriptions,
        }
    }
}

impl Render for Settings {
    fn render(&mut self, _: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let desktop = self.desktop.read(cx);
        let text = |zh, en| desktop.text(zh, en);
        let muted = cx.theme().muted_foreground;
        let mut appearances = ButtonGroup::new("appearance-options").small();
        for (index, (label, mode)) in [
            (text("跟随系统", "System"), None),
            (text("浅色", "Light"), Some(ThemeMode::Light)),
            (text("深色", "Dark"), Some(ThemeMode::Dark)),
        ]
        .into_iter()
        .enumerate()
        {
            appearances = appearances.child(
                Button::new(("appearance", index))
                    .small()
                    .label(label)
                    .selected(desktop.appearance == mode)
                    .on_click(cx.listener(move |this, _, window, cx| {
                        this.desktop.update(cx, |desktop, cx| {
                            desktop.appearance = mode;
                            if let Some(mode) = mode {
                                Theme::change(mode, Some(window), cx);
                            } else {
                                Theme::sync_system_appearance(Some(window), cx);
                            }
                            cx.notify();
                        });
                    })),
            );
        }
        let mut languages = ButtonGroup::new("language-options").small();
        for (index, (label, language)) in [
            (text("跟随系统", "System"), None),
            ("简体中文", Some(false)),
            ("English", Some(true)),
        ]
        .into_iter()
        .enumerate()
        {
            languages = languages.child(
                Button::new(("language", index))
                    .label(label)
                    .selected(desktop.language == language)
                    .on_click(cx.listener(move |this, _, window, cx| {
                        this.desktop.update(cx, |desktop, cx| {
                            desktop.language = language;
                            window.set_window_title(desktop.settings_title());
                            desktop.notify_status(cx);
                        });
                    })),
            );
        }
        let mut states = ButtonGroup::new("status-options").small();
        for (index, (label, status)) in [
            (text("示例读数", "Sample"), DemoStatus::Sample),
            (text("已过期", "Stale"), DemoStatus::Stale),
            (text("离线", "Offline"), DemoStatus::Offline),
        ]
        .into_iter()
        .enumerate()
        {
            states = states.child(
                Button::new(("status", index))
                    .small()
                    .label(label)
                    .selected(desktop.status == status)
                    .on_click(cx.listener(move |this, _, _, cx| {
                        this.desktop.update(cx, |desktop, cx| {
                            desktop.status = status;
                            desktop.notify_status(cx);
                        });
                    })),
            );
        }
        div().v_flex().size_full().p_5().gap_4()
            .track_focus(&self.focus)
            .bg(cx.theme().background).text_color(cx.theme().foreground).text_sm()
            .on_action(|_: &CloseWindow, window, _| window.remove_window())
            .child(div().text_lg().font_weight(FontWeight::SEMIBOLD).child(text("原型设置", "Prototype settings")))
            .child(div().text_xs().text_color(muted).child(text(
                "所有读数均为演示，未连接设备。设置仅影响本次运行。",
                "Demo readings only. No device connected. Settings apply only to this session.",
            )))
            .child(div().v_flex().gap_2().child(text("外观", "Appearance")).child(appearances))
            .child(div().v_flex().gap_2().child(text("语言", "Language")).child(languages))
            .child(div().v_flex().gap_2().child(text("演示连接状态", "Simulated connection state")).child(states))
            .child(div().text_xs().text_color(muted).child(text(
                "真实 MCP 连接、安全凭据存储与休眠恢复将在后续核心移植阶段接入。",
                "Live MCP, secure credential storage and sleep/wake monitoring are not implemented yet.",
            )))
            .child(div().flex_1())
            .child(div().h_flex().justify_end().gap_2()
                .child(Button::new("open-panel").small().label(text("打开面板", "Open panel"))
                    .on_click(cx.listener(|this, _, _, cx| {
                        if let Err(error) = Desktop::show_panel(&this.desktop, false, cx) {
                            eprintln!("prototype: {error}");
                        }
                    })))
                .child(Button::new("done").small().primary().label(text("完成", "Done"))
                    .on_click(|_, window, _| window.remove_window())))
    }
}
