/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class About.StorageView : Switchboard.SettingsPage {
    private Gtk.ListBox storage_list;
    private Granite.Placeholder placeholder;
    private Gtk.ListBoxRow? root_row;
    private Gtk.ProgressBar root_usage_bar;
    private Gtk.Label root_usage_label;
    private Gtk.Label root_warning_label;
    private Gtk.Label root_subtitle_label;

    public StorageView () {
        Object (
            icon: new ThemedIcon ("drive-harddisk"),
            title: _("Storage"),
            description: _("View storage capacity and available space.")
        );
    }

    construct {
        placeholder = new Granite.Placeholder (_("No storage devices found")) {
            description = _("Connect a storage device to see it listed here."),
            icon = new ThemedIcon ("drive-harddisk-symbolic")
        };

        storage_list = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE,
            activate_on_single_click = false,
            vexpand = true
        };
        storage_list.set_placeholder (placeholder);
        storage_list.add_css_class (Granite.STYLE_CLASS_RICH_LIST);

        root_row = create_root_row ();
        storage_list.append (root_row);

        var margin_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_top = 18,
            margin_bottom = 18,
            margin_start = 18,
            margin_end = 18,
            hexpand = true,
            vexpand = true
        };

        var scrolled = new Gtk.ScrolledWindow () {
            vexpand = true,
            child = storage_list
        };

        margin_box.append (scrolled);

        var clamp = new Adw.Clamp () {
            child = margin_box,
            hexpand = true
        };

        child = clamp;

        load_storage_info.begin ();
    }

    private async void load_storage_info () {
        bool has_entries = false;

        clear_drive_rows ();

        try {
            var root_file = GLib.File.new_for_path ("/");
            var info = yield root_file.query_filesystem_info_async (
                GLib.FileAttribute.FILESYSTEM_SIZE + "," + GLib.FileAttribute.FILESYSTEM_FREE,
                GLib.Priority.DEFAULT,
                null
            );

            uint64 total_bytes = info.get_attribute_uint64 (GLib.FileAttribute.FILESYSTEM_SIZE);
            uint64 free_bytes = info.get_attribute_uint64 (GLib.FileAttribute.FILESYSTEM_FREE);
            uint64 used_bytes = total_bytes > free_bytes ? total_bytes - free_bytes : 0;

            double fraction = 0.0;
            if (total_bytes > 0) {
                fraction = (double) used_bytes / (double) total_bytes;
            }
            fraction = clamp_fraction (fraction);

            var usage_text = _("Using %s of %s (%s free)").printf (
                GLib.format_size (used_bytes),
                GLib.format_size (total_bytes),
                GLib.format_size (free_bytes)
            );

            var warning_text = free_bytes <= 15UL * 1024 * 1024 * 1024
                ? _("⚠️ Only %s free. It's time to clean house before things grind to a halt!").printf (GLib.format_size (free_bytes))
                : _("Plenty of breathing room, but keep an eye on big downloads.");

            root_subtitle_label.label = _("System volume mounted at /");
            root_usage_bar.fraction = fraction;
            root_usage_label.label = usage_text;
            root_warning_label.label = warning_text;

            if (fraction >= 0.9) {
                root_row.add_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);
                root_usage_bar.add_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);
            } else if (fraction >= 0.75) {
                root_row.remove_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);
                root_row.add_css_class (Granite.STYLE_CLASS_WARNING);
                root_usage_bar.remove_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);
            } else {
                root_row.remove_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);
                root_row.remove_css_class (Granite.STYLE_CLASS_WARNING);
                root_usage_bar.remove_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);
            }

            has_entries = true;
        } catch (Error e) {
            warning ("Failed to query root filesystem info: %s", e.message);
        }

        try {
            UDisks.Client client = yield new UDisks.Client (null);
            foreach (unowned var obj in client.object_manager.get_objects ()) {
                var udisks_object = (UDisks.Object) obj;
                var drive = udisks_object.drive;

                if (drive == null || drive.removable || drive.ejectable) {
                    continue;
                }

                string name = "";
                if (drive.vendor != null && drive.vendor.strip ().length > 0) {
                    name = drive.vendor.strip ();
                }

                if (drive.model != null && drive.model.strip ().length > 0) {
                    if (name.length > 0) {
                        name += " ";
                    }
                    name += drive.model.strip ();
                }

                if (name.length == 0) {
                    name = _("Internal Drive");
                }

                string subtitle = _("%s total capacity").printf (GLib.format_size (drive.size));

                append_drive_row (name, subtitle, 0.0, null);

                has_entries = true;
            }
        } catch (Error e) {
            warning ("Failed to enumerate drives: %s", e.message);
        }

        if (!has_entries) {
            placeholder.icon = new ThemedIcon ("media-removable");
            placeholder.description = _("No internal storage devices were detected.");
        }
    }

    private static double clamp_fraction (double value) {
        if (value < 0.0) {
            return 0.0;
        }

        if (value > 1.0) {
            return 1.0;
        }

        return value;
    }

    private Gtk.ListBoxRow create_root_row () {
        Gtk.Box content_box;
        var row = create_row ("drive-harddisk", _("Root Volume"), out content_box);

        root_subtitle_label = new Gtk.Label ("") {
            xalign = 0,
            wrap = true
        };
        root_subtitle_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        root_warning_label = new Gtk.Label ("") {
            xalign = 0,
            wrap = true
        };
        root_warning_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        root_usage_bar = new Gtk.ProgressBar () {
            hexpand = true
        };

        root_usage_label = new Gtk.Label ("") {
            xalign = 0,
            wrap = true
        };
        root_usage_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        content_box.append (root_subtitle_label);
        content_box.append (root_warning_label);
        content_box.append (root_usage_bar);
        content_box.append (root_usage_label);

        return row;
    }

    private void append_drive_row (string title, string subtitle, double usage_fraction, string? usage_description) {
        Gtk.Box content_box;
        var row = create_row ("drive-harddisk", title, out content_box);

        if (subtitle.length > 0) {
            var subtitle_label = new Gtk.Label (subtitle) {
                xalign = 0,
                wrap = true
            };
            subtitle_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
            content_box.append (subtitle_label);
        }

        if (usage_description != null) {
            var usage_label = new Gtk.Label (usage_description) {
                xalign = 0,
                wrap = true
            };
            usage_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
            content_box.append (usage_label);
        }

        storage_list.append (row);
    }

    private Gtk.ListBoxRow create_row (string icon_name, string title, out Gtk.Box content_box) {
        var row = new Gtk.ListBoxRow ();
        var row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };

        var icon_widget = new Gtk.Image.from_icon_name (icon_name) {
            pixel_size = 32,
            valign = Gtk.Align.CENTER
        };

        content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            hexpand = true
        };

        var title_label = new Gtk.Label (title) {
            xalign = 0,
            wrap = true
        };
        content_box.append (title_label);

        row_box.append (icon_widget);
        row_box.append (content_box);

        row.child = row_box;
        return row;
    }

    private void clear_drive_rows () {
        var child = storage_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            if (child != root_row) {
                storage_list.remove (child);
            }
            child = next;
        }
    }
}
