defmodule Egapp.XMPP.Conference.Stanza do
  require Egapp.Constants, as: Const

  import Egapp.XMPP.Stanza, only: [iq_template: 2, build_iq_attrs: 3]

  alias Egapp.XMPP.Element
  alias Egapp.XMPP.Conference.Query

  def iq(%{"type" => "get"} = attrs, {"query", child_attrs, child_data}, state) do
    {status, result} = Query.query(child_attrs, child_data, state)

    resp =
      result
      |> Enum.map(fn {conn, content} ->
        resp =
          iq_template(build_iq_attrs(attrs, status, state), content)
          |> :xmerl.export_simple_element(:xmerl_xml)

        {conn, resp}
      end)

    {:ok, resp}
  end

  def iq(
        %{"type" => "get"} = attrs,
        {"vCard", %{"xmlns" => Const.xmlns_vcard()}, _child_data},
        state
      ) do
    resp =
      iq_template(build_iq_attrs(attrs, :ok, state), Element.vcard())
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, [{state.to, resp}]}
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
