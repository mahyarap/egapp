defmodule Egapp.SASL.Plain do
  require Ecto.Query

  @behaviour Egapp.SASL

  @impl Egapp.SASL
  def authenticate(message) do
    [xmlcdata: token] = message
    result =
      Base.decode64!(token)
      |> String.split(<<0::utf8>>)
      |> Enum.slice(1, 2)

    username = Enum.at(result, 0)
    password = Enum.at(result, 1)
    user =
      Ecto.Query.from(
        u in Egapp.Repo.User,
        where: u.username == ^username
      )
      |> Egapp.Repo.one()

    if username == user.username and password == user.password do
      {:success, user}
    else
      {:failure, nil}
    end
  end
end
