using Gtk;
using WebKit;

public class winks: Window {

    private const string TITLE = "winks";
    private const string HOME_URL = "http://www.google.co.uk/";
    private const string DEFAULT_PROTOCOL = "http";

    private Regex protocol_regex;
    private Regex search_check_regex;

    private Entry url_bar;
    private WebView web_view;
    private Label status_bar;
		private ScrolledWindow scrolled_window;

    public winks () {
        this.title = winks.TITLE;
        set_default_size (1024, 768);

        try {
            this.protocol_regex = new Regex (".*://.*");
            this.search_check_regex = new Regex (".*[.].*");
        } catch (RegexError e) {
            critical ("%s", e.message);
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
        this.status_bar = new Label ("winks v0.01");
        this.status_bar.xalign = 0;
        var vbox = new VBox (false, 0);
        vbox.pack_start (this.url_bar, false, true, 0);
        vbox.add (scrolled_window);
        vbox.pack_start (this.status_bar, false, true, 0);
        add (vbox);
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
				this.scrolled_window.set_events(Gdk.EventMask.KEY_PRESS_MASK);
				this.scrolled_window.key_press_event.connect(ProcessKeyPress);
    }

		private bool ProcessKeyPress( Gdk.EventKey KeyPressed ) {
				this.status_bar.set_text ("Keypress: "+KeyPressed.str);
				switch (KeyPressed.str) {
						case "r":
								this.web_view.reload ();
						break;

						case "b":
								if (this.web_view.can_go_back ())
										this.web_view.go_back ();
						break;

						case "f":
								if (this.web_view.can_go_forward ())
										this.web_view.go_forward ();
						break;

						case "u":
								this.url_bar.grab_focus ();
						break;
				}
				return true;
		}

    private void on_activate () {
        var url = this.url_bar.text;
        if (!this.protocol_regex.match (url)) {
            if (!this.search_check_regex.match (url)) {
                url = "http://www.google.co.uk/search?q="+url;
            } else {
                url = "%s://%s".printf (winks.DEFAULT_PROTOCOL, url);	
            }
        } 
        this.web_view.open (url);
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
