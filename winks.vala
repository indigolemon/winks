/*
* winks.vala - Lightweight Browser
*
* Copyright (C) 2010 Graham Thomson <graham.thomson@gmail.com>
* Released under the GNU General Public License (GPL) version 2.
* See COPYING
*/

using Gtk;
using WebKit;

public class winks: Window {

	private const string TITLE = "winks";
	private const string HOME_URL = "http://www.google.co.uk/";
	private const string DEFAULT_PROTOCOL = "http";
	private const string VERSION_STRING = "Winks 0.01a";

	private Regex protocol_regex;
	private Regex search_check_regex;

	private Entry url_bar;
	private WebView web_view;
	private Label status_bar;
	private ScrolledWindow scrolled_window;

	public winks () {
		this.title = winks.TITLE;
		set_default_size (1024, 768);

		// Setup required Regex objects
		try {
			this.protocol_regex = new Regex (".*://.*");
			this.search_check_regex = new Regex (".*[.].*");
		} catch (RegexError e) {
			critical ("%s", e.message);
		}

		// Load icon for Application
		try {
			this.icon = new Gdk.Pixbuf.from_file ("winks.png");
		} catch (Error e) {
			stderr.printf ("Could not load application icon: %s\n", e.message);
		}

		create_widgets ();
		connect_signals ();
		this.url_bar.grab_focus ();
	}

	private void create_widgets () {
		this.url_bar = new Entry ();
		this.web_view = new WebView ();
		this.scrolled_window = new ScrolledWindow (null, null);
		this.scrolled_window.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		this.scrolled_window.add (this.web_view);
		this.status_bar = new Label ("Welcome to "+VERSION_STRING);
		this.status_bar.xalign = 1;
		this.status_bar.xpad = 5;
		this.status_bar.set_single_line_mode (true);
		var top_bar = new HBox (true, 0);
		top_bar.add (this.url_bar);
		top_bar.add (this.status_bar);
		var main_area = new VBox (false, 0);
		main_area.pack_start (top_bar, false, true, 0);
		main_area.add (this.scrolled_window);
		add (main_area);
	}

	private void connect_signals () {
		this.destroy.connect (Gtk.main_quit);
		this.url_bar.activate.connect (on_activate);
		this.web_view.title_changed.connect ((source, frame, title) => {
			this.title = "%s - %s".printf (title, winks.TITLE);
		});
		this.web_view.load_committed.connect ((source, frame) => {
			this.url_bar.text = frame.get_uri ();
		});
		this.web_view.new_window_policy_decision_requested.connect (
		(source, frame, request, action, decision) => {
			this.status_bar.set_text ("New Window Requested | "+VERSION_STRING);
			this.web_view.open (request.get_uri ());
			return true;
		});
		this.scrolled_window.set_events(Gdk.EventMask.KEY_PRESS_MASK);
		this.scrolled_window.key_press_event.connect(ProcessKeyPress);
	}

	private bool ProcessKeyPress( Gdk.EventKey KeyPressed ) {
		string performed_action = "";
		switch (KeyPressed.str.up ()) {
			case "R":
				this.web_view.reload ();
				performed_action = "Page reloaded";
			break;

			case "B":
				if (this.web_view.can_go_back ()){
					this.web_view.go_back ();
					performed_action = "Gone Back 1 Page";
				}
			break;

			case "F":
				if (this.web_view.can_go_forward ()){
					this.web_view.go_forward ();
					performed_action = "Gone Forward 1 Page";
				}
			break;

			case "H":
				this.web_view.open (winks.HOME_URL);
				performed_action = "Homepage Loaded";
			break;

			case "U":
				this.url_bar.grab_focus ();
				performed_action = "Edit URL and hit Enter";
			break;

			case "I":
				this.url_bar.text = "";
				this.url_bar.grab_focus ();
				performed_action = "Type Command/URL and hit Enter";
			break;
		}
		if (performed_action.length > 0)
			this.status_bar.set_text (performed_action+" | "+VERSION_STRING);
		return true;
	}

	private void on_activate () {
		var url = this.url_bar.text;
		// Check for a command
		if (url.substring(0,1) == ":") {
			ProcessCommand (url);
		} else {
			// we have a url or search
			if (!this.protocol_regex.match (url)) {
				if (!this.search_check_regex.match (url)) {
					url = "http://www.google.co.uk/search?q="+url;
				} else {
					url = "%s://%s".printf (winks.DEFAULT_PROTOCOL, url);
				}
			} 
			this.web_view.open (url);
		}
		this.scrolled_window.grab_focus ();
	}

	public void ProcessCommand (string PassedCmd) {
		switch (PassedCmd) {
			case ":quit":
			case ":q":
				Gtk.main_quit ();
			break;

			default:
				this.status_bar.set_text ("'"+PassedCmd+"' Unknown Command | "+VERSION_STRING);
			break;
		}
	}

	public void start (string passed_url) {
		show_all ();
		if (this.protocol_regex.match (passed_url)) {
			this.web_view.open (passed_url);
		} else {
			this.web_view.open (winks.HOME_URL);
		}
	}

	public static int main (string[] args) {
		Gtk.init (ref args);

		var browser = new winks ();

		if (args[1] != null) {
			browser.start (args[1]); 
		} else {
			browser.start (winks.HOME_URL);
		}

		Gtk.main ();

		return 0;
	}
}
