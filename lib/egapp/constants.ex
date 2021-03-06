defmodule Constants do
  @moduledoc """
  An alternative to use @constant_name value approach to defined reusable
  constants in elixir. 

  This module offers an approach to define these in a module that can be shared
  with other modules. They are implemented with macros so they can be used in
  guards and matches

  ## Examples: 
  Create a module to define your shared constants
      defmodule MyConstants do
        use Constants
        define something,   10
        define another,     20
      end

  Use the constants
      defmodule MyModule do
        require MyConstants
        alias MyConstants, as: Const
        def myfunc(item) when item == Const.something, do: Const.something + 5
        def myfunc(item) when item == Const.another, do: Const.another
      end
  """
  
  defmacro __using__(_opts) do
    quote do
      import Constants
    end
  end

  @doc "Define a constant"
  defmacro const(name, value) do
    quote do
      defmacro unquote(name), do: unquote(value)
    end
  end
end

defmodule Egapp.Constants do
  @moduledoc false
  use Constants

  const xml_decl,           '<?xml version="1.0"?>'
  const xmlns_bind,         "urn:ietf:params:xml:ns:xmpp-bind"
  const xmlns_bytestreams,  "http://jabber.org/protocol/bytestreams"
  const xmlns_c2s,          "jabber:client"
  const xmlns_chatstates,   "http://jabber.org/protocol/chatstates"
  const xmlns_disco_info,   "http://jabber.org/protocol/disco#info"
  const xmlns_disco_items,  "http://jabber.org/protocol/disco#items"
  const xmlns_last,         "jabber:iq:last"
  const xmlns_muc,          "http://jabber.org/protocol/muc"
  const xmlns_muc_traffic,  "http://jabber.org/protocol/muc#traffic"
  const xmlns_ping,         "urn:xmpp:ping"
  const xmlns_roster,       "jabber:iq:roster"
  const xmlns_sasl,         "urn:ietf:params:xml:ns:xmpp-sasl"
  const xmlns_session,      "urn:ietf:params:xml:ns:xmpp-session"
  const xmlns_stanza,       "urn:ietf:params:xml:ns:xmpp-stanzas"
  const xmlns_stream,       "http://etherx.jabber.org/streams"
  const xmlns_stream_error, "urn:ietf:params:xml:ns:xmpp-streams"
  const xmlns_time,         "urn:xmpp:time"
  const xmlns_vcard,        "vcard-temp"
  const xmlns_version,      "jabber:iq:version"
  const xmpp_version,       "1.0"
end
