defmodule Egapp.XMPP.Conference.Stanza do
  import Egapp.XMPP.Stanza, only: [iq_template: 2, build_iq_attrs: 3]

  alias Egapp.XMPP.Conference.Element

  def iq(%{"type" => "get"} = attrs, {"query", child_attrs, child_data}, state) do
    content = Element.query(child_attrs, child_data, state)
    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
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
