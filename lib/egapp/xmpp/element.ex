defmodule Egapp.XMPP.Element do
  require Ecto.Query
  require Egapp.Constants, as: Const

  alias Egapp.XMPP.Jid

  @doc """
  RFC6120 4.3.2
  """
  def features(content) do
    {
      :"stream:features",
      content
    }
  end

  @doc """
  RFC6120 7.4
  RFC6120 7.6.1
  """
  def bind(attrs, data, state) do
    Egapp.XMPP.Server.Element.bind(attrs, data, state)
  end

  def bind() do
    Egapp.XMPP.Server.Element.bind()
  end

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

  def success do
    {
      :success,
      [xmlns: Const.xmlns_sasl()],
      []
    }
  end

  def failure(reason) do
    {
      :failure,
      [xmlns: Const.xmlns_sasl()],
      [reason]
    }
  end

  @doc """
  RFC3921 3
  """
  def session(attrs, data, state) do
    Egapp.XMPP.Server.Element.session(attrs, data, state)
  end

  def session do
    Egapp.XMPP.Server.Element.session()
  end

  def query(%{"to" => to} = attrs, data, state) do
    case Jid.partial_parse(to) do
      %Jid{domainpart: "egapp.im"} ->
        Egapp.XMPP.Server.Element.query(attrs, data, state)

      %Jid{domainpart: "conference.egapp.im"} ->
        Egapp.XMPP.Conference.Element.query(attrs, data, state)

      _ ->
        raise "should not get here"
    end
  end

  def query(attrs, data, state) do
    Egapp.XMPP.Server.Element.query(attrs, data, state)
  end

  def query_template(attrs, content), do: {:query, attrs, content}

  def vcard(%{"xmlns" => Const.xmlns_vcard()} = attrs, data, state) do
    Egapp.XMPP.Server.Element.vcard(attrs, data, state)
  end

  def ping(%{"xmlns" => Const.xmlns_ping()} = attrs, data, state) do
    Egapp.XMPP.Server.Element.ping(attrs, data, state)
  end

  def time(%{"xmlns" => Const.xmlns_time()} = attrs, data, state) do
    Egapp.XMPP.Server.Element.time(attrs, data, state)
  end

  def feature(xmlns), do: {:feature, [var: xmlns], []}

  def identity(category, type), do: {:identity, [category: category, type: type], []}

  def item(attrs, content), do: {:item, attrs, content}

  def bad_request_error(type, desc \\ nil) do
    error(type, error_template(:"bad-request"), desc)
  end

  def feature_not_implemented_error(type, desc \\ nil) do
    error(type, error_template(:"feature-not-implemeted"), desc)
  end

  defp error(type, err, desc) do
    desc = if desc, do: error_desc(desc), else: []
    {:error, [type: Atom.to_charlist(type)], [err, desc]}
  end

  defp error_desc(desc), do: {:text, [xmlns: Const.xmlns_stanza], [String.to_charlist(desc)]}

  defp error_template(element), do: {element, [xmlns: Const.xmlns_stanza], []}
end
