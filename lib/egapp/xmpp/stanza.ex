defmodule Egapp.XMPP.Stanza do
  require Ecto.Query
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Element
  alias Egapp.JidConnRegistry

  def iq(%{"type" => "get"} = attrs, {"query", child_attrs, child_data}, state) do
    content = Element.query(child_attrs, child_data, state)
    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => "get"} = attrs, {"vCard", child_attrs, child_data}, state) do
    content = Element.vcard(child_attrs, child_data, state)
    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(
        %{"type" => "get"} = attrs,
         {"query", %{"xmlns" => Const.xmlns_bytestreams()}, _data},
        state
      ) do
      content = Element.query(
        [xmlns: Const.xmlns_disco_info()],
        [
          {
            :error,
            [type: 'cancel'],
            [
              {
                :"feature-not-implemented",
                [xmlns: 'urn:ietf:params:xml:ns:xmpp-stanzas'],
                []
              }
            ]
          }
        ]
      )

    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, apply(state.mod, :send, [state.to, resp])}
  end

  def iq(
        %{"type" => "get"} = attrs,
         {"query", %{"xmlns" => Const.xmlns_version()}, _data},
        state
      ) do
    content = Element.query(
      [xmlns: Const.xmlns_version()],
      [
        {:name, ['egapp']},
        {:version, ['1.0.0']}
      ]
    )

    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, apply(state.mod, :send, [state.to, resp])}
  end

  def iq(
        %{"type" => "get"} = attrs,
         {"query", %{"xmlns" => Const.xmlns_last()}, _data},
        state
      ) do
    content = Element.query(
      [xmlns: Const.xmlns_last(), seconds: 3650],
      []
    )

    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, apply(state.mod, :send, [state.to, resp])}
  end

  def iq(
        %{"type" => "get"} = attrs, {"time", %{"xmlns" => Const.xmlns_time()}, _data},
        state
      ) do
    {:ok, now} = DateTime.now("Etc/UTC")
    iso_time = DateTime.to_iso8601(now)
    content = {
      :time,
      [xmlns: Const.xmlns_time()],
      [
        {:tzo, ['+00:00']},
        {:utc, [String.to_charlist(iso_time)]}
      ]
    }

    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, apply(state.mod, :send, [state.to, resp])}
  end

  def iq(%{"type" => "get"} = attrs, {"ping", child_attrs, child_data}, state) do
    content = Element.ping(child_attrs, child_data, state)
    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => "set"} = attrs, {"query", _child_attrs, _data}, state) do
    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), [])
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, apply(state.mod, :send, [state.to, resp])}
  end

  def iq(%{"type" => "set"} = attrs, {"bind", child_attrs, child_data}, state) do
    resp =
      iq_template(
        build_iq_attrs(attrs, 'result', state),
        Element.bind(child_attrs, child_data, state)
      )
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  def iq(%{"type" => "set"} = attrs, {"session", _child_attrs, _child_data}, state) do
    resp =
      iq_template(build_iq_attrs(attrs, 'result', state), [])
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:ok, resp}
  end

  defp iq_template(%{id: id, type: type, from: from}, content) do
    iq_attrs = [
      id: id,
      type: type
    ]
    attrs = if from, do: [{:from, from} | iq_attrs], else: iq_attrs
    content = if content, do: [content], else: []

    {:iq, attrs, content}
  end

  defp build_iq_attrs(attrs, type, state) do
    %{
      lang: Map.get(state.client, "xml:lang", "en"),
      id: Map.get(attrs, "id"),
      from: Map.get(attrs, "from") || "egapp.im",
      type: type
    }
  end

  def message({attrs, [{:xmlel, "composing", _child_attrs, _data}]}) do
  end

  def message({attrs, [{:xmlel, "paused", _child_attrs, _data}]}) do
  end

  def message({attrs, [{:xmlel, "active", _child_attrs, _data}]}) do
  end

  def message({attrs, [{:xmlel, "active", _child_attrs, _data}, body]}) do
    {:xmlel, "body", [], [xmlcdata: msg]} = body

    {
      :message,
      [
        from: String.to_charlist(attrs["from"]),
        id: String.to_charlist(attrs["id"]),
        to: String.to_charlist(attrs["to"]),
        type: 'chat',
        "xml:lang": 'en'
      ],
      [{:body, [String.to_charlist(msg)]}]
    }
  end

  def message({attrs, [{:xmlel, "body", [], [xmlcdata: msg]}]}) do
    {
      :message,
      [
        from: 'foo@egapp.im/4db06f06-1ea4-11dc-aca3-000bcd821bfb',
        id: '#{attrs["id"]}',
        to: 'gooz@egapp.im/4db06f06-1ea4-11dc-aca3-000bcd821bfb',
        type: 'chat',
        "xml:lang": 'en'
      ],
      [{:body, [String.to_charlist(msg)]}]
    }
  end

  def presence(attrs, child, state) do
    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster, where: r.user_id == ^state.client.id)
      |> Egapp.Repo.one()
      |> Egapp.Repo.preload(:users)

    resp =
    roster.users
    |> Enum.map(fn contact ->
      {contact, JidConnRegistry.get(contact.username <> "@egapp.im")}
    end)
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(fn {contact, conn} ->
      attrs = %{
        from: "#{state.client.bare_jid}/#{state.client.resource}",
        to: contact.username <> "@egapp.im"
      }
      resp =
        presence_template(attrs, [])
        |> :xmerl.export_simple_element(:xmerl_xml)
      {conn, resp}
    end)
  end

  defp presence_template(%{from: from, to: to}, content) do
    {:presence, [from: from, to: to], content}
  end

  defp build_presence_attrs(attrs, state) do
    %{
      lang: Map.get(state.client, "xml:lang", "en"),
      id: Map.get(attrs, "id"),
      from: Map.get(attrs, "from") || "egapp.im",
      to: Map.get(attrs, "to")
    }
  end
end
