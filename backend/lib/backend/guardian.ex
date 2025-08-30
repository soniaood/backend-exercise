defmodule Backend.Guardian do
  @moduledoc """
  Guardian implementation module.

  Responsible for encoding/decoding JWTs and mapping between tokens and user resources.
  Defines how the subject is built for tokens and how to load the user from claims.

  Used by the authentication pipeline to protect API endpoints and to load the current user.
  """

  use Guardian, otp_app: :backend

  alias Backend.Users

  def subject_for_token(%{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :reason_for_error}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Users.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_claims) do
    {:error, :reason_for_error}
  end
end
