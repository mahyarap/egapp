defmodule Egapp.XMPP.Stream do
  require Egapp.Constants, as: Const
  alias Egapp.XMPP.Element

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
  def stream(%{"xmlns:stream" => Const.xmlns_stream(), "version" => Const.xmpp_version()} = attrs, state) do
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
      |> prepend_xml_decl

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
      |> prepend_xml_decl

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
      |> prepend_xml_decl

    {:error, resp}
  end

  @doc """
  Returns other stream error cases

  RFC6120 4.7.5
  RFC6120 4.8.1
  """
  def stream(attrs, state) do
    {content, reason} =
      cond do
        not Map.has_key?(attrs, "xmlns:stream") ->
          {bad_namespace_prefix_error(), :bad_namespace_prefix}

        not Map.has_key?(attrs, "version") ->
          {unsupported_version_error(), :unsupported_version}

        true ->
          "should not get here"
      end

    resp =
      stream_template(build_stream_attrs(attrs, state), content)
      |> :xmerl.export_simple_element(:xmerl_xml)
      |> prepend_xml_decl

    {:error, resp}
  end

  def error(error, attrs, state) do
    content =
      case error do
        :bad_namespace_prefix -> bad_namespace_prefix_error()
      end

    stream_template(build_stream_attrs(attrs, state), content)
    |> :xmerl.export_simple_element(:xmerl_xml)
    |> prepend_xml_decl
  end

  defp stream_template(%{id: id, lang: lang, from: from}, content) do
    stream_attrs = [
      from: 'egapp.im',
      id: id,
      version: '1.0',
      "xml:lang": lang,
      xmlns: 'jabber:client',
      "xmlns:stream": Const.xmlns_stream
    ]

    attrs = if from, do: [{:to, from} | stream_attrs], else: stream_attrs
    content = if content, do: [content], else: []

    {
      :"stream:stream",
      attrs,
      content
    }
  end

  defp build_stream_attrs(attrs, state) do
    %{
      lang: Map.get(state.client, "xml:lang", "en"),
      id: Enum.random(10_000_000..99_999_999),
      from: Map.get(attrs, "from")
    }
  end

  defp error_template(err) do
    {
      :"stream:error",
      [],
      [err]
    }
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

  defp bad_format_error do
    error_template({
      :"bad-format",
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
