/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

namespace Clocks {

public class Toolbar : Gd.MainToolbar {
    public enum Mode {
        NORMAL,
        SELECTION,
        STANDALONE
    }

    private List<Gtk.Widget> buttons;
    private List<Clock> clocks;

    [CCode (notify = false)]
    public Mode mode {
        get {
            return _mode;
        }

        set {
            if (_mode != value) {
                _mode = value;

                show_modes = (_mode == Mode.NORMAL);

                if (_mode == Mode.SELECTION) {
                    get_style_context ().add_class ("selection-mode");
                } else {
                    get_style_context ().remove_class ("selection-mode");
                }

                notify_property ("mode");
            }
        }
    }

    private Mode _mode;

    public Toolbar () {
        Object (show_modes: true, vexpand: false);
        get_style_context ().add_class (Gtk.STYLE_CLASS_MENUBAR);
    }

    public signal void clock_changed (Clock clock);

    public void add_clock (Clock clock) {
        var button = add_mode (clock.label) as Gtk.ToggleButton;
        clocks.prepend (clock);
        button.toggled.connect(() => {
            if (button.active) {
                clock_changed (clock);
            }
        });
    }

    // we wrap add_button so that we can keep track of which
    // buttons to remove in clear() without removing the radio buttons
    public new Gtk.Button add_button (string? icon_name, string? label, bool pack_start) {
        var button = base.add_button (icon_name, label, pack_start);
        buttons.prepend (button);
        return (Gtk.Button) button;
    }

    public new void clear () {
        foreach (Gtk.Widget button in buttons) {
            button.destroy ();
        }
    }
}

private class DigitalClockRenderer : Gtk.CellRendererPixbuf {
    const int CHECK_ICON_SIZE = 40;

    public string text { get; set; }
    public string subtext { get; set; }
    public string css_class { get; set; }
    public bool active { get; set; default = false; }
    public bool toggle_visible { get; set; default = false; }

    public DigitalClockRenderer () {
    }

    public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
        var context = widget.get_style_context ();

        context.save ();
        context.add_class ("clocks-digital-renderer");
        context.add_class (css_class);

        cr.save ();
        Gdk.cairo_rectangle (cr, cell_area);
        cr.clip ();

        // draw background
        if (pixbuf != null) {
            base.render (cr, widget, background_area, cell_area, flags);
        } else {
            context.render_frame (cr, cell_area.x, cell_area.y, cell_area.width, cell_area.height);
            context.render_background (cr, cell_area.x, cell_area.y, cell_area.width, cell_area.height);
        }

        cr.translate (cell_area.x, cell_area.y);

        // for now the space around the digital clock is hardcoded and relative
        // to the image width (not the width of the cell which may be larger in
        // case of long city names).
        // We need to know the width to create the pango layouts
        int pixbuf_margin = 0;
        if (pixbuf != null) {
            pixbuf_margin = (int) ((cell_area.width - pixbuf.width) / 2);
        }

        int margin = 12 + pixbuf_margin;
        int padding = 12;
        int w = cell_area.width - 2 * margin;

        // create the layouts so that we can measure them
        var layout = widget.create_pango_layout ("");
        layout.set_markup ("<span size='xx-large'><b>%s</b></span>".printf (text), -1);
        layout.set_width (w * Pango.SCALE);
        layout.set_alignment (Pango.Alignment.CENTER);
        int text_w, text_h;
        layout.get_pixel_size (out text_w, out text_h);

        Pango.Layout? layout_subtext = null;
        int subtext_w = 0;
        int subtext_h = 0;
        int subtext_pad = 0;
        if (subtext != null) {
            layout_subtext = widget.create_pango_layout ("");
            layout_subtext.set_markup ("<span size='medium'>%s</span>".printf (subtext), -1);
            layout_subtext.set_width (w * Pango.SCALE);
            layout_subtext.set_alignment (Pango.Alignment.CENTER);
            layout_subtext.get_pixel_size (out subtext_w, out subtext_h);
            subtext_pad = 6;
            // We just assume the first line is the longest
            var line = layout_subtext.get_line (0);
            Pango.Rectangle ink_rect, log_rect;
            line.get_pixel_extents (out ink_rect, out log_rect);
            subtext_w = log_rect.width;
        }

        // measure the actual height and coordinates (xpad is ignored for now)
        int h = 2 * padding + text_h + subtext_h + subtext_pad;
        int x = margin;
        int y = (cell_area.height - h) / 2;

        context.add_class ("inner");

        // draw inner rectangle background
        context.render_frame (cr, x, y, w, h);
        context.render_background (cr, x, y, w, h);

        // draw text
        context.render_layout (cr, x, y + padding, layout);
        if (subtext != null) {
            context.render_layout (cr, x, y + padding + text_h + subtext_pad, layout_subtext);
        }

        context.restore ();

        // draw the overlayed checkbox
        if (toggle_visible) {
            int xpad, ypad, x_offset;
            get_padding (out xpad, out ypad);

            if (widget.get_direction () == Gtk.TextDirection.RTL) {
                x_offset = xpad;
            } else {
                x_offset = cell_area.width - CHECK_ICON_SIZE - xpad;
            }

            int check_x = x_offset;
            int check_y = cell_area.height - CHECK_ICON_SIZE - ypad;

            context.save ();
            context.add_class (Gtk.STYLE_CLASS_CHECK);

            if (active) {
                context.set_state (Gtk.StateFlags.ACTIVE);
            }

            context.render_check (cr, check_x, check_y, CHECK_ICON_SIZE, CHECK_ICON_SIZE);

            context.restore ();
        }

        cr.restore ();
    }

    public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area, out int x_offset, out int y_offset, out int width, out int height) {
        base.get_size (widget, cell_area, out x_offset, out y_offset, out width, out height);
        width += CHECK_ICON_SIZE / 4;
        height += CHECK_ICON_SIZE / 4;
    }
}

public class IconView : Gtk.IconView {
    public enum Mode {
        NORMAL,
        SELECTION
    }

    public enum Column {
        SELECTED,
        LABEL,
        ITEM,
        COLUMNS
    }

    public Mode mode {
        get {
            return _mode;
        }

        set {
            if (_mode != value) {
                _mode = value;
                // clear selection
                if (_mode != Mode.SELECTION) {
                    unselect_all ();
                }

                thumb_renderer.toggle_visible = (_mode == Mode.SELECTION);
                queue_draw ();
            }
        }
    }

    private Mode _mode;
    private DigitalClockRenderer thumb_renderer;

    public IconView (owned Gtk.CellLayoutDataFunc thumb_data_func) {
        Object (selection_mode: Gtk.SelectionMode.NONE, mode: Mode.NORMAL);

        model = new Gtk.ListStore (Column.COLUMNS, typeof (bool), typeof (string), typeof (Object));

        get_style_context ().add_class ("content-view");
        set_column_spacing (20);
        set_margin (16);

        thumb_renderer = new DigitalClockRenderer ();
        thumb_renderer.set_alignment (0.5f, 0.5f);
        thumb_renderer.set_fixed_size (160, 160);
        pack_start (thumb_renderer, false);
        add_attribute (thumb_renderer, "active", Column.SELECTED);
        set_cell_data_func (thumb_renderer, (owned) thumb_data_func);

        var text_renderer = new Gtk.CellRendererText ();
        text_renderer.set_alignment (0.5f, 0.5f);
        text_renderer.set_fixed_size (160, -1);
        text_renderer.wrap_width = 140;
        text_renderer.wrap_mode = Pango.WrapMode.WORD_CHAR;
        pack_start (text_renderer, true);
        add_attribute (text_renderer, "markup", Column.LABEL);
    }

    public override bool button_press_event (Gdk.EventButton event) {
        var path = get_path_at_pos ((int) event.x, (int) event.y);
        if (path != null) {
            if (mode == Mode.SELECTION) {
                var store = (Gtk.ListStore) model;
                Gtk.TreeIter i;
                if (store.get_iter (out i, path)) {
                    bool selected;
                    store.get (i, Column.SELECTED, out selected);
                    store.set (i, Column.SELECTED, !selected);
                    selection_changed ();
                }
            } else {
                item_activated (path);
            }
        }

        return false;
    }

    public void add_item (string name, Object item) {
        var store = (Gtk.ListStore) model;
        var label = GLib.Markup.escape_text (name);
        Gtk.TreeIter i;
        store.append (out i);
        store.set (i, Column.SELECTED, false, Column.LABEL, label, Column.ITEM, item);
    }

    // Redefine selection handling methods since we handle selection manually

    public new List<Gtk.TreePath>? get_selected_items () {
        List<Gtk.TreePath>? items = null;
        model.foreach ((model, path, iter) => {
            bool selected;
            ((Gtk.ListStore) model).get (iter, Column.SELECTED, out selected);
            if (selected) {
                items.prepend (path);
            }
            return false;
        });
        items.reverse ();
        return (owned) items;
    }

    public new void select_all () {
        var model = get_model () as Gtk.ListStore;
        model.foreach ((model, path, iter) => {
            ((Gtk.ListStore) model).set (iter, Column.SELECTED, true);
            return false;
        });
        selection_changed ();
    }

    public new void unselect_all () {
        var model = get_model () as Gtk.ListStore;
        model.foreach ((model, path, iter) => {
            ((Gtk.ListStore) model).set (iter, Column.SELECTED, false);
            return false;
        });
        selection_changed ();
    }

    public void remove_selected () {
        var paths =  get_selected_items ();
        paths.reverse ();
        foreach (Gtk.TreePath path in paths) {
            Gtk.TreeIter i;
            if (((Gtk.ListStore) model).get_iter (out i, path)) {
                ((Gtk.ListStore) model).remove (i);
            }
        }
        selection_changed ();
    }
}

public class ContentView : Gtk.Bin {
    private const int SELECTION_TOOLBAR_WIDTH = 300;

    public bool empty { get; private set; default = true; }

    private Gtk.Widget empty_page;
    private IconView icon_view;
    private Toolbar main_toolbar;
    private GLib.MenuModel selection_menu;
    private Gtk.Toolbar selection_toolbar;
    private Gtk.Overlay overlay;
    private Gtk.ScrolledWindow scrolled_window;

    public ContentView (Gtk.Widget e, IconView iv, Toolbar t) {
        empty_page = e;
        icon_view = iv;
        main_toolbar = t;

        var builder = Utils.load_ui ("menu.ui");
        selection_menu = builder.get_object ("selection-menu") as GLib.MenuModel;

        overlay = new Gtk.Overlay ();
        overlay.add (icon_view);

        selection_toolbar = create_selection_toolbar ();
        overlay.add_overlay (selection_toolbar);

        scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.add (overlay);

        var model = icon_view.get_model ();
        model.row_inserted.connect(() => {
            update_empty_view (model);
        });
        model.row_deleted.connect(() => {
            update_empty_view (model);
        });

        icon_view.notify["mode"].connect (() => {
            if (icon_view.mode == IconView.Mode.SELECTION) {
                main_toolbar.mode = Toolbar.Mode.SELECTION;
            } else if (icon_view.mode == IconView.Mode.NORMAL) {
                main_toolbar.mode = Toolbar.Mode.NORMAL;
            }
        });

        icon_view.selection_changed.connect (() => {
            var items = icon_view.get_selected_items ();
            var n_items = items.length ();

            string label;
            if (n_items == 0) {
                label = _("Click on items to select them");
            } else {
                label = ngettext ("%d selected", "%d selected", n_items).printf (n_items);
            }
            main_toolbar.set_labels (label, null);

            selection_toolbar.set_visible (n_items != 0);
        });

        add (empty_page);
    }

    public signal void delete_selected ();

    private Gtk.Toolbar create_selection_toolbar () {
        var toolbar = new Gtk.Toolbar ();
        toolbar.show_arrow = false;
        toolbar.icon_size = Gtk.IconSize.LARGE_TOOLBAR;
        toolbar.halign = Gtk.Align.CENTER;
        toolbar.valign = Gtk.Align.END;
        toolbar.margin_bottom = 40;
        toolbar.get_style_context ().add_class ("osd");
        toolbar.set_size_request (SELECTION_TOOLBAR_WIDTH, -1);
        toolbar.no_show_all = true;

        var delete_button = new Gtk.Button.with_label (_("Delete"));
        delete_button.hexpand = true;
        delete_button.clicked.connect (() => {
            delete_selected ();
        });

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        hbox.hexpand = true;
        hbox.add (delete_button);

        var item = new Gtk.ToolItem ();
        item.set_expand (true);
        item.add (hbox);
        item.show_all ();

        toolbar.insert (item, -1);

        return toolbar;
    }

    private void update_empty_view (Gtk.TreeModel model) {
        Gtk.TreeIter i;

        var child = get_child ();
        if (model.get_iter_first (out i)) {
            if (child != scrolled_window) {
                remove (child);
                add (scrolled_window);
                empty = false;
            }
        } else {
            if (child != empty_page) {
                remove (child);
                add (empty_page);
                empty = true;
            }
        }
        show_all ();
    }

    public void update_toolbar () {
        switch (main_toolbar.mode) {
        case Toolbar.Mode.SELECTION:
            var done_button = main_toolbar.add_button (null, _("Done"), false);
            main_toolbar.set_labels (_("Click on items to select them"), null);
            main_toolbar.set_labels_menu (selection_menu);
            done_button.get_style_context ().add_class ("suggested-action");
            done_button.clicked.connect (() => {
                selection_toolbar.set_visible (false);
                icon_view.mode = IconView.Mode.NORMAL;
            });
            break;
        case Toolbar.Mode.NORMAL:
            main_toolbar.set_labels (null, null);
            main_toolbar.set_labels_menu (null);
            var select_button = main_toolbar.add_button ("object-select-symbolic", null, false);
            select_button.clicked.connect (() => {
                icon_view.mode = IconView.Mode.SELECTION;
            });
            bind_property ("empty", select_button, "sensitive", BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
            break;
        }
    }
}

public class AmPmToggleButton : Gtk.Button {
    public enum AmPm {
        AM,
        PM
    }

    public AmPm choice {
        get {
            return _choice;
        }
        set {
            if (_choice != value) {
                _choice = value;
                stack.visible_child = _choice == AmPm.AM ? am_label : pm_label;
            }
        }
    }

    private AmPm _choice;
    private Gd.Stack stack;
    private Gtk.Label am_label;
    private Gtk.Label pm_label;

    public AmPmToggleButton () {
        stack = new Gd.Stack ();
        stack.duration = 0;

        var str = (new GLib.DateTime.utc (1, 1, 1, 0, 0, 0)).format ("%p");
        am_label = new Gtk.Label (str);

        str = (new GLib.DateTime.utc (1, 1, 1, 12, 0, 0)).format ("%p");
        pm_label = new Gtk.Label (str);

        stack.add (am_label);
        stack.add (pm_label);
        add (stack);

        clicked.connect (() => {
            choice = choice == AmPm.AM ? AmPm.PM : AmPm.AM;
        });

        choice = AmPm.AM;
        stack.visible_child = am_label;
        show_all ();
    }
}

} // namespace Clocks