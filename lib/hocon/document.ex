defmodule Hocon.Document do
  @moduledoc """

  """

  alias Hocon.Document

  defstruct root: %{}

  def new() do
    %Document{}
  end

  def put(doc, key, %Document{root: value}) do
    put(doc, key, value)
  end
  def put(%Document{root: root}, key, value) do
   path = key
          |> String.split(".")
          |> Enum.map(fn str -> String.trim(str) end)
          |> Enum.filter(fn str -> str != nil end)
    %Document{root: put_path(root, path, value)}
  end

  def put_path(root, [key], value) do
    Map.put(root, key, value)
  end
  def put_path(root, [head|tail], value) do
    Map.put(root, head, put_path(Map.get(root, head, %{}), tail, value))
  end

end