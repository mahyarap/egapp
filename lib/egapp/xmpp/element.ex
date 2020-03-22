defmodule Egapp.XMPP.Element do
  require Egapp.Constants, as: Const

  @doc """
  RFC6120 4.3.2
  """
  def features(content), do: {:"stream:features", content}

  @doc """
  RFC6120 7.4
  RFC6120 7.6.1
  """
  def bind(content), do: {:bind, [xmlns: Const.xmlns_bind()], [content]}

  def bind, do: {:bind, [xmlns: Const.xmlns_bind()], []}

  @doc """
  RFC6120 6.3.3
  RFC6120 6.4.1
  """
  def mechanisms do
    {
      :mechanisms,
      [xmlns: Const.xmlns_sasl()],
      [
        # Server preference order
        # {:mechanism, ['ANONYMOUS']},
        # {:mechanism, ['DIGEST-MD5']},
        {:mechanism, ['PLAIN']}
      ]
    }
  end

  def challenge do
    {
      :challenge,
      [xmlns: Const.xmlns_sasl()],
      [
        'cmVhbG09ImZvbyIsbm9uY2U9IjEyMyIsY2hhcnNldD11dGYtOCxhbGdvcml0aG09bWQ1LXNlc3MsY2lwaGVyPSJkZXMiCg=='
      ]
    }
  end

  def success, do: {:success, [xmlns: Const.xmlns_sasl()], []}

  def failure(reason), do: {:failure, [xmlns: Const.xmlns_sasl()], [reason]}

  def session, do: {:session, [xmlns: Const.xmlns_session()], []}

  def query_template(attrs, content), do: {:query, attrs, content}

  def vcard, do: {:vCard, [xmlns: Const.xmlns_vcard()], []}

  def ping, do: {:ping, [xmlns: Const.xmlns_ping()], []}

  def time(timezone, time) do
    {:time, [xmlns: Const.xmlns_time()], [{:tzo, [timezone]}, {:utc, [time]}]}
  end

  def feature(xmlns), do: {:feature, [var: xmlns], []}

  def identity(category, type), do: {:identity, [category: category, type: type], []}

  def item(attrs, content), do: {:item, attrs, content}

  def jid(content), do: {:jid, [], [content]}

  def status(code), do: {:status, [code: Integer.to_charlist(code)], []}

  def x(attrs, content), do: {:x, attrs, content}

  def bad_request_error(type, desc \\ nil) do
    error(type, error_template(:"bad-request"), desc)
  end

  def feature_not_implemented_error(type, desc \\ nil) do
    error(type, error_template(:"feature-not-implemeted"), desc)
  end

  def service_unavailable_error(type, desc \\ nil) do
    error(type, error_template(:"service-unavailable"), desc)
  end

  defp error(type, err, desc) do
    desc = if desc, do: error_desc(desc), else: []
    {:error, [type: Atom.to_charlist(type)], [err, desc]}
  end

  defp error_desc(desc), do: {:text, [xmlns: Const.xmlns_stanza()], [String.to_charlist(desc)]}

  defp error_template(element), do: {element, [xmlns: Const.xmlns_stanza()], []}
end
