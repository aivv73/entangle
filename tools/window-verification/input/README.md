# X11 input adapter

This is the source of `bend-ui-test@0.1.0.1`, content hash
`0x5b025dca427389b7a69b3b41292c7682`, adapted for Bend 2.0.40's `Press`
event and inline `Tool` layout. The original source is
`https://entire.com/et/bend-engine/bend-ui-test`.

The hub version still uses the removed `Mouse` constructor. Keep this adapter
in Entangle's source revision so native window verification builds with
the same event ABI as the production bridge. Key taps, primary clicks, Close,
and X11 error trapping retain the original interface and behavior.
