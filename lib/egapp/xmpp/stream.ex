defmodule Egapp.XMPP.Stream do
  require Egapp.Constants, as: Const
  alias Egapp.Utils
  alias Egapp.XMPP.Jid
  alias Egapp.XMPP.Element
  alias Egapp.JidConnRegistry

  @doc """
  RFC6120 4.7
  RFC6120 4.7.1
  RFC6120 4.7.2
  RFC6120 4.7.3
  RFC6120 4.7.4
  RFC6120 4.7.5
  RFC6120 4.8.1
  RFC6120 4.8.2
  RFC6120 4.8.3
  """
  def stream(
        %{"xmlns:stream" => Const.xmlns_stream(), "version" => Const.xmpp_version()} = attrs,
        state
      ) do
    features =
      if Map.get(state.client, :is_authenticated) do
        [Element.bind(), Element.session()]
      else
        [Element.mechanisms()]
      end

    content = Element.features(features)

    resp =
      stream_template(build_stream_attrs(attrs, state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)
      # Remove </stream:stream> which is automatically created
      |> Enum.reverse()
      |> tl()
      |> Enum.reverse()
      |> prepend_xml_decl()

    {:ok, resp}
  end

  @doc """
  Returns "invalid-namespace" if the stream header is invalid

  RFC6120 4.8.1
  """
  def stream(%{"xmlns:stream" => _, "version" => Const.xmpp_version()} = attrs, state) do
    resp =
      stream_template(build_stream_attrs(attrs, state), invalid_namespace_error())
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> prepend_xml_decl()

    {:error, resp}
  end

  @doc """
  Returns "unsupported-version" if the version is invalid

  RFC6120 4.7.5
  """
  def stream(%{"xmlns:stream" => _, "version" => _} = attrs, state) do
    resp =
      stream_template(build_stream_attrs(attrs, state), unsupported_version_error())
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> prepend_xml_decl()

    {:error, resp}
  end

  @doc """
  Returns other stream error cases

  RFC6120 4.7.5
  RFC6120 4.8.1
  """
  def stream(attrs, state) do
    content =
      cond do
        not Map.has_key?(attrs, "xmlns:stream") ->
          bad_namespace_prefix_error()
        not Map.has_key?(attrs, "version") ->
          unsupported_version_error()
        true ->
          "should not get here"
      end

    resp =
      stream_template(build_stream_attrs(attrs, state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> prepend_xml_decl()

    {:error, resp}
  end

  def error(:bad_namespace_prefix, attrs, state) do
    stream_template(build_stream_attrs(attrs, state), bad_namespace_prefix_error())
    |> :xmerl.export_simple_element(:xmerl_xml)
    |> prepend_xml_decl()
  end

  def error(:bad_format, attrs, state) do
    stream_template(build_stream_attrs(attrs, state), bad_format_error())
    |> :xmerl.export_simple_element(:xmerl_xml)
    |> prepend_xml_decl()
  end

  def error(:not_well_formed, attrs, state) do
    stream_template(build_stream_attrs(attrs, state), not_well_formed_error())
    |> :xmerl.export_simple_element(:xmerl_xml)
    |> prepend_xml_decl()
  end

  defp build_stream_attrs(attrs, state) do
    %{
      lang: Map.get(state.client, "xml:lang", "en"),
      id: Utils.generate_id(),
      from: Map.get(attrs, "from")
    }
  end

  defp stream_template(%{id: id, lang: lang, from: from}, content) do
    stream_attrs = [
      from: 'egapp.im',
      id: id,
      version: '1.0',
      "xml:lang": lang,
      xmlns: 'jabber:client',
      "xmlns:stream": Const.xmlns_stream()
    ]

    attrs = if from, do: [{:to, from} | stream_attrs], else: stream_attrs
    content = if content, do: [content], else: []

    {
      :"stream:stream",
      attrs,
      content
    }
  end

  def auth(attrs, data, state) do
    result =
      case Egapp.SASL.authenticate!(attrs["mechanism"], data) do
        {:ok, user} ->
          jid = %Jid{
            localpart: user.username,
            domainpart: "egapp.im",
            resourcepart: Utils.generate_id() |> Integer.to_string()
          }

          state =
            state
            |> put_in([:client, :is_authenticated], true)
            |> put_in([:client, :id], user.id)
            |> put_in([:client, :jid], jid)

          JidConnRegistry.put(Jid.bare_jid(jid), state.to)
          {:ok, Element.success(), state}

        {:error, _} ->
          {:error, Element.failure({:"not-authorized", []}), state}

        {:challenge, _} ->
          {:error, nil, state}
      end

    {status, element, state} = result
    resp = :xmerl.export_simple_element(element, :xmerl_xml)

    {status, resp, state}
  end

  defp error_template(err) do
    {
      :"stream:error",
      [],
      [err]
    }
  end

  defp bad_format_error do
    error_template({
      :"bad-format",
      [xmlns: Const.xmlns_stream_error()],
      []
    })
  end

  defp not_well_formed_error do
    error_template({
      :"not-well-formed",
      [xmlns: Const.xmlns_stream_error()],
      []
    })
  end

  defp invalid_namespace_error do
    error_template({
      :"invalid-namespace",
      [xmlns: Const.xmlns_stream_error()],
      []
    })
  end

  defp unsupported_version_error do
    error_template({
      :"unsupported-version",
      [xmlns: Const.xmlns_stream_error()],
      []
    })
  end

  defp bad_namespace_prefix_error do
    error_template({
      :"bad-namespace-prefix",
      [xmlns: Const.xmlns_stream_error()],
      []
    })
  end

  defp prepend_xml_decl(content) do
    ['<?xml version="1.0"?>' | content]
  end
end
