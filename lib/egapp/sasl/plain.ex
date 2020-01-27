defmodule Egapp.SASL.Plain do
  require Ecto.Query

  @behaviour Egapp.SASL

  @impl Egapp.SASL
  def authenticate(message) do
    result =
      Base.decode64!(message)
      |> String.split(<<0::utf8>>)
      |> Enum.slice(1, 2)

    {username, password} =
      case result do
        [username, password] -> {username, password}
        [] -> {"", ""}
      end

    user =
      Ecto.Query.from(
        u in Egapp.Repo.User,
        where: u.username == ^username
      )
      |> Egapp.Repo.one()

    cond do
      user == nil ->
        {:error, :user_not_found}

      password != user.password ->
        {:error, :password_mismatch}

      true ->
        {:ok, user}
    end
  end
end
