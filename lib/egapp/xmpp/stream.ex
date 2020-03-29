defmodule Egapp.XMPP.Stream do
  require Egapp.Constants, as: Const

  alias Egapp.Utils
  alias Egapp.Config
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

    resp =
      Element.features(features)
      |> stream_template(build_stream_attrs(attrs, state))
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> remove_last_closing_tag()
      |> prepend_xml_decl()

    {:ok, resp}
  end

  @doc """
  Returns "invalid-namespace" if the stream header is invalid

  RFC6120 4.8.1
  """
  def stream(%{"xmlns:stream" => val} = attrs, state) when val != Const.xmlns_stream() do
    resp =
      invalid_namespace_error()
      |> stream_template(build_stream_attrs(attrs, state))
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> prepend_xml_decl()

    {:error, resp}
  end

  @doc """
  Returns "unsupported-version" if the version is invalid

  RFC6120 4.7.5
  """
  def stream(%{"version" => val} = attrs, state) when val != Const.xmpp_version() do
    resp =
      unsupported_version_error()
      |> stream_template(build_stream_attrs(attrs, state))
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> prepend_xml_decl()

    {:error, resp}
  end

  @doc """
  Returns "invalid-namespace" if the stream header is missing

  RFC6120 4.8.1
  """
  def stream(attrs, state) when not is_map_key(attrs, "xmlns:stream") do
    resp =
      bad_namespace_prefix_error()
      |> stream_template(build_stream_attrs(attrs, state))
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> prepend_xml_decl()

    {:error, resp}
  end

  @doc """
  Returns "unsupported-version" if the version is missing

  RFC6120 4.7.5
  """
  def stream(attrs, state) when not is_map_key(attrs, "version") do
    resp =
      unsupported_version_error()
      |> stream_template(build_stream_attrs(attrs, state))
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> prepend_xml_decl()

    {:error, resp}
  end

  def build_stream_attrs(attrs, state) do
    %{
      lang: Map.get(state.client, "xml:lang", "en"),
      id: Utils.generate_id(),
      from: Map.get(attrs, "from")
    }
  end

  def stream_template(content, %{id: id, lang: lang, from: from}) do
    stream_attrs = [
      from: Config.get(:domain_name),
      id: id,
      version: Const.xmpp_version(),
      "xml:lang": lang,
      xmlns: 'jabber:client',
      "xmlns:stream": Const.xmlns_stream()
    ]

    attrs = if from, do: [{:to, from} | stream_attrs], else: stream_attrs
    content = if content, do: [content], else: []
    {:"stream:stream", attrs, content}
  end

  def auth(%{"xmlns" => Const.xmlns_sasl(), "mechanism" => mechanism}, data, state)
      when mechanism in ["PLAIN", "DIGEST-MD5"] do
    message =
      case data do
        [] -> ""
        [xmlcdata: message] -> message
      end

    sasl_mechanisms = Map.get(state, :sasl_mechanisms) || Config.get(:sasl_mechanisms)
    jid_conn_registry = Map.get(state, :jid_conn_registry, JidConnRegistry)

    {status, element, state} =
      case Egapp.SASL.authenticate!(mechanism, message, sasl_mechanisms) do
        {:ok, user} ->
          jid = %Jid{
            localpart: user.username,
            domainpart: Config.get(:domain_name),
            resourcepart: Utils.generate_id() |> Integer.to_string()
          }

          state =
            state
            |> put_in([:client, :is_authenticated], true)
            |> put_in([:client, :id], user.id)
            |> put_in([:client, :jid], jid)

          jid_conn_registry.put(Jid.bare_jid(jid), {jid, state.to})
          {:ok, Element.success(), state}

        {:error, _} ->
          {:retry, Element.failure({:"not-authorized", []}), state}

        {:challenge, _} ->
          {:error, nil, state}
      end

    resp = :xmerl.export_simple_element(element, :xmerl_xml)
    {status, resp, state}
  end

  def auth(%{"xmlns" => Const.xmlns_sasl()} = attrs, _data, state)
      when is_map_key(attrs, "mechanism") do
    resp =
      invalid_namespace_error()
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:error, resp, state}
  end

  def auth(attrs, _data, state) when is_map_key(attrs, "mechanism") do
    resp =
      invalid_mechanism_error()
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:error, resp, state}
  end

  def auth(attrs, _data, state) do
    content =
      cond do
        not Map.has_key?(attrs, "xmlns") ->
          invalid_namespace_error()

        not Map.has_key?(attrs, "mechanism") ->
          invalid_mechanism_error()

        true ->
          "should not get here"
      end

    resp =
      content
      |> auth_error_template()
      |> :xmerl.export_simple_element(:xmerl_xml)

    {:error, resp, state}
  end

  def bad_format_error do
    stream_error_template(:"bad-format")
  end

  def not_well_formed_error do
    stream_error_template(:"not-well-formed")
  end

  def not_authorized_error do
    stream_error_template(:"not-authorized")
  end

  def invalid_namespace_error do
    stream_error_template(:"invalid-namespace")
  end

  def invalid_xml_error do
    stream_error_template(:"invalid-xml")
  end

  def invalid_mechanism_error do
    stream_error_template(:"invalid-mechanism")
  end

  def unsupported_version_error do
    stream_error_template(:"unsupported-version")
  end

  def bad_namespace_prefix_error do
    stream_error_template(:"bad-namespace-prefix")
  end

  def stream_end, do: ['</stream:stream>']

  defp stream_error_template(element) do
    {:"stream:error", [], [{element, [xmlns: Const.xmlns_stream_error()], []}]}
  end

  defp auth_error_template(err), do: {:failure, [xmlns: Const.xmlns_sasl()], [err]}

  defp prepend_xml_decl(content) do
    [Const.xml_decl | content]
  end

  defp remove_last_closing_tag(content) do
    content
    |> Enum.reverse()
    |> tl()
    |> Enum.reverse()
  end
end
