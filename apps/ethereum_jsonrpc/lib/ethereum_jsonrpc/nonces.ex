defmodule EthereumJSONRPC.Nonces do
  @moduledoc """
  Nonce params and errors from a batch request from `eth_getTransactionCount`.
  """

  alias EthereumJSONRPC.Nonce

  defstruct params_list: [],
            errors: []

  @typedoc """
   * `params_list` - all the nonce params from requests that succeeded in the batch.
   * `errors` - all the errors from requests that failed in the batch.
  """
  @type t :: %__MODULE__{params_list: [Nonce.params()], errors: [Nonce.error()]}

  @doc """
    Generates a list of `eth_getTransactionCount` JSON-RPC requests for the given parameters.

    This function takes a map of request IDs to parameter maps and transforms them
    into a list of JSON-RPC request structures for fetching nonces.

    ## Parameters
    - `id_to_params`: A map where keys are request IDs and values are maps
      containing `block_quantity` and `address` for each request.

    ## Returns
    A list of maps, each representing a JSON-RPC request with the following
    structure:
    - `jsonrpc`: The JSON-RPC version (always "2.0").
    - `id`: The request identifier.
    - `method`: The RPC method name (always "eth_getTransactionCount").
    - `params`: A list containing the address and block identifier.
  """
  @spec requests(%{id => %{block_quantity: block_quantity, address: address}}) :: [
          %{jsonrpc: String.t(), id: id, method: String.t(), params: [address | block_quantity]}
        ]
        when id: EthereumJSONRPC.request_id(),
             block_quantity: EthereumJSONRPC.quantity(),
             address: EthereumJSONRPC.address()
  def requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{block_quantity: block_quantity, address: address}} ->
      Nonce.request(%{id: id, block_quantity: block_quantity, address: address})
    end)
  end

  @doc """
   Processes responses from `eth_getTransactionCount` JSON-RPC calls and converts them into a structured format.

   This function takes a list of responses from `eth_getTransactionCount` calls and a map of
   request IDs to their corresponding parameters. It sanitizes the responses,
   processes each one, and accumulates the results into a `Nonces` struct.

   ## Parameters
   - `responses`: A list of response maps from `eth_getTransactionCount` calls. Each map
     contains an `:id` key and either a `:result` or `:error` key.
   - `id_to_params`: A map where keys are request IDs and values are maps
     containing `block_quantity` and `address` for each request.

   ## Returns
   A `Nonces` struct containing:
   - `params_list`: A list of successfully fetched nonce parameters.
   - `errors`: A list of errors encountered during the process.
  """
  @spec from_responses(
          [%{:id => EthereumJSONRPC.request_id(), optional(:error) => map(), optional(:result) => String.t()}],
          %{non_neg_integer() => %{block_quantity: String.t(), address: String.t()}}
        ) :: t()
  def from_responses(responses, id_to_params) do
    responses
    |> EthereumJSONRPC.sanitize_responses(id_to_params)
    |> Enum.map(&Nonce.from_response(&1, id_to_params))
    |> Enum.reduce(
      %__MODULE__{},
      fn
        {:ok, params}, %__MODULE__{params_list: params_list} = acc ->
          %__MODULE__{acc | params_list: [params | params_list]}

        {:error, reason}, %__MODULE__{errors: errors} = acc ->
          %__MODULE__{acc | errors: [reason | errors]}
      end
    )
  end
end
