defmodule Egapp.XMPP.Conference do
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Element

  def address do
    "conference.egapp.im"
  end

  def identity do
    Element.identity('conference', 'text')
  end

  def features do
    [
      Element.feature(Const.xmlns_disco_info()),
      Element.feature(Const.xmlns_disco_items()),
      Element.feature(Const.xmlns_vcard()),
      Element.feature(Const.xmlns_muc())
    ]
  end

  def presence(_attrs, _data, state) do
    attrs = %{
      from: "folan@conference.egapp.im/Alice",
      to: "mahan@egapp.im"
    }
    resp =
      Egapp.XMPP.Stanza.presence_template(attrs, [])
      |> :xmerl.export_simple_element(:xmerl_xml)

    [{state.to, resp}]
  end
end
