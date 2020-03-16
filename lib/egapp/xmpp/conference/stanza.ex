defmodule Egapp.XMPP.Conference.Stanza do
  import Egapp.XMPP.Stanza, only: [iq_template: 2, build_iq_attrs: 3]

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
