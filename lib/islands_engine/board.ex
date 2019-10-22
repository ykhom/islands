defmodule IslandsEngine.Board do
  alias IslandsEngine.{Coordinate, Island}

  def new(), ​do​: %{}

  def position_island(board, key, %Island{} = island) ​do​
    ​case​ overlaps_existing_island?(board, key, island) ​do​
      true  -> {​:error​, ​:overlapping_island​}
      false -> Map.put(board, key, island)
    ​end​
  end​

  defp overlaps_existing_island?(board, new_key, new_island) ​do​
    Enum.any?(board, ​fn​ {key, island} ->
      key != new_key ​and​ Island.overlaps?(island, new_island)
    end​)
  ​end

  def all_islands_positioned?(board), ​do​:
    Enum.all?(Island.types, &(Map.has_key?(board, &1)))

  def guess(board, %Coordinate{} = coordinate) ​do​
    board
    |> check_all_islands(coordinate)
    |> guess_response(board)
  end​

  defp check_all_islands(board, coordinate) ​do​
    Enum.find_value(board, ​:miss​, ​fn​ {key, island} ->
      ​case​ Island.guess(island, coordinate) ​do​
        {​:hit​, island} -> {key, island}
        ​:miss​          -> false
      ​end​
    ​end​)
  ​end

  defp guess_response({key, island}, board) ​do​
    board = %{board | key => island}
    {​:hit​, forest_check(board, key), win_check(board), board}
  ​end​
  defp guess_response(​:miss​, board), ​do​: {​:miss​, ​:none​, ​:no_win​, board}

  defp forest_check(board, key) ​do​
    ​case​ forested?(board, key) ​do​
      true  -> key
      false -> ​:none​
    ​end​
  ​end​
​ 
  defp forested?(board, key) ​do​
    board
    |> Map.fetch!(key)
    |> Island.forested?()
  ​end

  defp win_check(board) ​do​
    ​case​ all_forested?(board) ​do​
      true  -> ​:win​
      false -> ​:no_win​
    ​end​
  end​
​ 
  ​defp all_forested?(board), ​do​:
    Enum.all?(board, ​fn​ {_key, island} -> Island.forested?(island) ​end​)



  @letters ~W(a b c d e f g h i j)
  @numbers [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

  #initialize board
  def start_link do
    Agent.start_link(fn -> initialized_board() end)
  end
  defp initialized_board() do
    Enum.reduce(keys(), %{}, fn(key, board) ->
      {:ok, coord} = Coordinate.start_link
      Map.put_new(board, key, coord)
    end )
  end
  defp keys() do
    for letter <- @letters, number <- @numbers do
      String.to_atom("#{letter}#{number}")
    end
  end

  #get board coordinate pid by name
  def get_coordinate(board, key) when is_atom key do
    Agent.get(board, fn board -> board[key] end)
  end

  #API for guess function
  def guess_coordinate(board, key) do
    get_coordinate(board, key)
    |> Coordinate.guess
  end

  #API for hit check function
  def coordinate_hit?(board, key) do
    get_coordinate(board, key)
    |> Coordinate.hit?
  end

  #API for set coordinate for Island
  def set_coordinate_in_island(board, key, island) do
    get_coordinate(board, key)
    |> Coordinate.set_in_island(island)
  end

  #API for checking to which island coordinate is related
  def coordinate_island(board, key) do
    get_coordinate(board, key)
    |> Coordinate.island
  end

  #API for getting board as a string
  def to_string(board) do
    "%{" <> string_body(board) <> "}"
  end
  defp string_body(board) do
    Enum.reduce(keys(), "", fn key, acc ->
      coord = get_coordinate(board, key)
      acc <> "#{key} => #{Coordinate.to_string(coord)},\n"
    end)
  end
end
