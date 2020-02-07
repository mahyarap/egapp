defmodule Egapp.XMPP.Element do
  require Ecto.Query
  require Egapp.Constants, as: Const

  alias Egapp.Config
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
  def bind(_attrs, _data, state) do
    full_jid = Jid.full_jid(state.client.jid) |> String.to_charlist()

    {
      :bind,
      [xmlns: Const.xmlns_bind()],
      [{:jid, [], [full_jid]}]
    }
  end

  def bind() do
    {
      :bind,
      [xmlns: Const.xmlns_bind()],
      []
    }
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
  def session do
    {
      :session,
      [xmlns: Const.xmlns_session()],
      []
    }
  end

  def query(%{"xmlns" => Const.xmlns_disco_items()}, _data, _state) do
    query_template([xmlns: Const.xmlns_disco_items()], [])
  end

  def query(%{"xmlns" => Const.xmlns_disco_info()}, _data, _state) do
    query_template(
      [xmlns: Const.xmlns_disco_info()],
      [
        {:identity, [category: 'server', type: 'im'], []},
        {:feature, [var: Const.xmlns_disco_info()], []},
        {:feature, [var: Const.xmlns_disco_items()], []},
        {:feature, [var: Const.xmlns_ping()], []},
        {:feature, [var: Const.xmlns_vcard()], []},
        {:feature, [var: Const.xmlns_version()], []},
        {:feature, [var: Const.xmlns_last()], []}
      ]
    )
  end

  def query(%{"xmlns" => Const.xmlns_roster()}, _data, state) do
    roster =
      Ecto.Query.from(r in Egapp.Repo.Roster, where: r.user_id == ^state.client.id)
      |> Egapp.Repo.one()
      |> Egapp.Repo.preload(:users)

    items =
      roster.users
      |> Enum.map(fn user ->
        jid = %Jid{
          localpart: user.username,
          domainpart: Config.get(:domain_name)
        }

        {
          :item,
          [jid: Jid.bare_jid(jid), subscription: 'both'],
          []
        }
      end)

    query_template([xmlns: Const.xmlns_roster()], items)
  end

  def query(%{"xmlns" => Const.xmlns_bytestreams()}, _data, _state) do
    content = [
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

    query_template([xmlns: Const.xmlns_disco_info()], content)
  end

  def query(%{"xmlns" => Const.xmlns_version()}, _data, _state) do
    content = [
      {:name, ['egapp']},
      {:version, ['1.0.0']}
    ]

    query_template([xmlns: Const.xmlns_version()], content)
  end

  def query(%{"xmlns" => Const.xmlns_last()}, _data, _state) do
    query_template([xmlns: Const.xmlns_last()], [])
  end

  defp query_template(attrs, content), do: {:query, attrs, content}

  def vcard(%{"xmlns" => Const.xmlns_vcard()}, _data, _state) do
    {
      :vCard,
      [xmlns: Const.xmlns_vcard()],
      []
    }
  end

  def ping(%{"xmlns" => Const.xmlns_ping()}, _data, _state) do
    {
      :ping,
      [xmlns: Const.xmlns_ping()],
      []
    }
  end

  def time(%{"xmlns" => Const.xmlns_time()}, _data, _state) do
    {:ok, now} = DateTime.now("Etc/UTC")
    iso_time = DateTime.to_iso8601(now)

    {
      :time,
      [xmlns: Const.xmlns_time()],
      [
        {:tzo, ['+00:00']},
        {:utc, [String.to_charlist(iso_time)]}
      ]
    }
  end
end
