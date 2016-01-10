/*
 * Copyright (c) 2011-2016 Wingpanel Developers (http://launchpad.net/wingpanel)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

public class DateTime.Indicator : Wingpanel.Indicator {
    private const string SETTINGS_EXEC = "/usr/bin/switchboard datetime";

    private Widgets.PanelLabel panel_label;

    private Gtk.Grid main_grid;

    private Wingpanel.Widgets.Button weather_button;

    private Gtk.Label weekday_label;
    private Gtk.Label date_label;

    private Widgets.Calendar calendar;

    private Wingpanel.Widgets.Button settings_button;

    private Gtk.Box event_box;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.DATETIME,
                display_name: _("Date & Time"),
                description: _("The date and time indicator"));
    }

    public override Gtk.Widget get_display_widget () {
        if (panel_label == null) {
            panel_label = new Widgets.PanelLabel ();
        }

        return panel_label;
    }

    public override Gtk.Widget? get_widget () {
        if (main_grid == null) {
            int position = 0;
            main_grid = new Gtk.Grid ();

            weekday_label = new Gtk.Label ("");
            weekday_label.get_style_context ().add_class ("h2");
            weekday_label.halign = Gtk.Align.START;
            weekday_label.margin_top = 10;
            weekday_label.margin_start = 20;
            main_grid.attach (weekday_label, 0, position++, 1, 1);

            date_label = new Gtk.Label ("");
            date_label.get_style_context ().add_class ("h3");
            date_label.halign = Gtk.Align.START;
            date_label.margin_start = 20;
            date_label.margin_top = 10;
            date_label.margin_bottom = 15;
            main_grid.attach (date_label, 0, position++, 1, 1);

            calendar = new Widgets.Calendar ();
            calendar.day_double_click.connect (() => {
                this.close ();
            });
            calendar.margin_bottom = 6;

            main_grid.attach (calendar, 0, position++, 1, 1);

            weather_button = new Wingpanel.Widgets.Button ("");
            weather_button.no_show_all = true;
            weather_button.set_tooltip_text (_("Data provided by OpenWeatherMap"));

            main_grid.attach (weather_button, 0, position++, 1, 1);

            event_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            main_grid.attach (event_box, 0, position++, 1, 1);

            settings_button = new Wingpanel.Widgets.Button (_("Date- &amp; Timesettings"));
            settings_button.clicked.connect (() => {
                show_settings ();
                this.close ();
            });

            main_grid.attach (new Wingpanel.Widgets.Separator (), 0, position++, 1, 1);

            main_grid.attach (settings_button, 0, position++, 1, 1);

            calendar.selection_changed.connect ((date) => {
                Idle.add (update_events);
                Idle.add (update_weather);
            });
            Services.WeatherManager.get_default ().today_updated.connect ((conditions) => {
                Idle.add (update_weather);
            });
        }

        this.visible = true;

        return main_grid;
    }

    private bool update_weather () {
        var conditions = Services.WeatherManager.get_default ().get_forecast (calendar.selected_date);
        if (conditions != null) {
            Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default ();
            try {
                Gdk.Pixbuf icon = icon_theme.load_icon (conditions.get_symbolic_icon (), 16, 0);
                weather_button.set_pixbuf (icon);
            } catch (Error e) {
                warning (e.message);
            }
            weather_button.set_caption ("%s, %s".printf (conditions.summary, conditions.get_temperature ()));
            weather_button.no_show_all = false;
            weather_button.show_all ();
        } else {
            weather_button.no_show_all = true;
            weather_button.hide ();
        }
        
        return false;
    }

    private void update_events_model (E.Source source, Gee.Collection<E.CalComponent> events) {
        Idle.add (update_events);
    }

    private bool update_events () {
        foreach (var w in event_box.get_children ()) {
            w.destroy ();
        }
        foreach (var e in Widgets.CalendarModel.get_default ().get_events (calendar.selected_date)) {
                var but = new Wingpanel.Widgets.Button (e.get_label ());
                Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default ();
                try {
                    Gdk.Pixbuf icon = icon_theme.load_icon (e.get_icon (), 16, 0);
                    but.set_pixbuf (icon);
                } catch (Error e) {
                    warning (e.message);
                }
                event_box.add (but);
                but.clicked.connect (() => {
                    calendar.show_date_in_maya (e.date);
                    this.close ();
                });
        }

        event_box.show_all ();
        return false;
    }

    public override void opened () {
        update_today_button ();
        calendar.show_today ();

        Services.TimeManager.get_default ().minute_changed.connect (update_today_button);
        Widgets.CalendarModel.get_default ().events_added.connect (update_events_model);
        Widgets.CalendarModel.get_default ().events_updated.connect (update_events_model);
        Widgets.CalendarModel.get_default ().events_removed.connect (update_events_model);
    }

    public override void closed () {
        Services.TimeManager.get_default ().minute_changed.disconnect (update_today_button);
        Widgets.CalendarModel.get_default ().events_added.disconnect (update_events_model);
        Widgets.CalendarModel.get_default ().events_updated.disconnect (update_events_model);
        Widgets.CalendarModel.get_default ().events_removed.disconnect (update_events_model);
    }

    private void update_today_button () {
        weekday_label.set_label (Services.TimeManager.get_default ().format ("%A"));
        date_label.set_label (Services.TimeManager.get_default ().format (_("%B %d, %Y")));
    }

    private void show_settings () {
        var cmd = new Granite.Services.SimpleCommand ("/usr/bin", SETTINGS_EXEC);
        cmd.run ();
    }
}

public Wingpanel.Indicator get_indicator (Module module) {
    debug ("Activating DateTime Indicator");
    var indicator = new DateTime.Indicator ();

    return indicator;
}