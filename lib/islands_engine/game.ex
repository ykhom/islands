defmodule IslandsEngine.Game do
  use GenServer
  alias IslandsEngine.{Board, Coordinate, Guesses, Island, Rules}

  defstruct player1: :none, player2: :none, fsm: :none
  @players [​:player1​, ​:player2​]

  #External APIs
  def start_link(name) when not is_binary(name) do
    GenServer.start_link(__MODULE__, name)
  end
  def add_player(game, name) ​when​ is_binary(name), ​do​:
    GenServer.call(game, {​:add_player​, name})
  def position_island(game, player, key, row, col) ​when​ player ​in​ @players, ​do​:
    GenServer.call(game, {​:position_island​, player, key, row, col})
  def set_islands(game, player) ​when​ player ​in​ @players, ​do​:
    GenServer.call(game, {​:set_islands​, player})​ 
  def guess_coordinate(game, player, row, col) ​when​ player ​in​ @players, ​do​:
    GenServer.call(game, {​:guess_coordinate​, player, row, col})

  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  def add_player(pid, name) when name != nil do
    GenServer.call(pid, {:add_player, name})
  end

  def set_island_coordinates(pid, player, island, coordinates)
    when is_atom player and is_atom island do
    GenServer.call(pid, {:set_island_coordinates, player, island, coordinates})
  end

  def set_islands(pid, player) when is_atom player do
    GenServer.call(pid, {:set_islands, player})
  end

  def guess_coordinate(pid, player, coordinate)
    when is_atom player and is_atom coordinate do
    GenServer.call(pid, {:guess, player, coordinate})
  end

  def call_demo(game) do
    GenServer.call(game, :demo)
  end

  #Handling callbacks

  def init(name) ​do​
    player1 = %{​name:​ name, ​board:​ Board.new(), ​guesses:​ Guesses.new()}
    player2 = %{​name:​ nil,  ​board:​ Board.new(), ​guesses:​ Guesses.new()}
    {​:ok​, %{​player1:​ player1, ​player2:​ player2, ​rules:​ %Rules{}}}
  end

  def handle_call({​:position_island​, player, key, row, col}, _from, state_data) do​
    board = player_board(state_data, player)
    with​ {​:ok​, rules} <-
​ 	        Rules.check(state_data.rules, {​:position_islands​, player}),
​ 	      {​:ok​, coordinate} <-
​ 	        Coordinate.new(row, col),
​ 	      {​:ok​, island} <-
​ 	        Island.new(key, coordinate),
​ 	      %{} = board <-
​ 	        Board.position_island(board, key, island)
    ​do​
​ 	  state_data
​ 	  |> update_board(player, board)
​ 	  |> update_rules(rules)
​ 	  |> reply_success(​:ok​)
    else​
​ 	  ​:error​ ->
​ 	    {​:reply​, ​:error​, state_data}
​ 	  {​:error​, ​:invalid_coordinate​} ->
​ 	    {​:reply​, {​:error​, ​:invalid_coordinate​}, state_data}
​ 	  {​:error​, ​:invalid_island_type​} ->
​ 	    {​:reply​, {​:error​, ​:invalid_island_type​}, state_data}
    end​
  end

  def handle_call({​:set_islands​, player}, _from, state_data) ​do​
​ 	  board = player_board(state_data, player)
​ 	  ​with​ {​:ok​, rules} <- Rules.check(state_data.rules, {​:set_islands​, player}),
​ 	       true         <- Board.all_islands_positioned?(board)
​ 	  ​do​
      state_data
      |> update_rules(rules)
      |> reply_success({​:ok​, board})
​ 	  ​else​
​ 	    ​:error​ -> {​:reply​, ​:error​, state_data}
​ 	    false  -> {​:reply​, {​:error​, ​:not_all_islands_positioned​}, state_data}
​ 	  ​end​
  end​
  def handle_call({​:guess_coordinate​, player_key, row, col}, _from, state_data)
​ 	​do​
​ 	  opponent_key = opponent(player_key)
​ 	  opponent_board = player_board(state_data, opponent_key)
​ 	  ​with​ {​:ok​, rules} <-
​ 	         Rules.check(state_data.rules, {​:guess_coordinate​, player_key}),
​ 	       {​:ok​, coordinate} <-
​ 	         Coordinate.new(row, col),
​ 	       {hit_or_miss, forested_island, win_status, opponent_board} <-
​ 	         Board.guess(opponent_board, coordinate),
​ 	       {​:ok​, rules} <-
​ 	         Rules.check(rules, {​:win_check​, win_status})
​ 	  ​do​
​ 	    state_data
​ 	    |> update_board(opponent_key, opponent_board)
​ 	    |> update_guesses(player_key, hit_or_miss, coordinate)
​ 	    |> update_rules(rules)
​ 	    |> reply_success({hit_or_miss, forested_island, win_status})
​ 	  ​else​
​ 	    ​:error​ ->
​ 	      {​:reply​, ​:error​, state_data}
​ 	    {​:error​, ​:invalid_coordinate​} ->
​ 	      {​:reply​, {​:error​, ​:invalid_coordinate​}, state_data}
​ 	  ​end​
  end​



  def init(name) do
    {:ok, player1} = Player.start_link(name)
    {:ok, player2} = Player.start_link()
    {:ok, fsm} = Rules.start_link
    {:ok, %Game{player1: player1, player2: player2, fsm: fsm}}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end
  #Handling of callback for adding player 2
  def handle_call({​:add_player​, name}, _from, state_data) ​do​
    ​with​ {​:ok​, rules} <- Rules.check(state_data.rules, ​:add_player​)
    ​do​
      state_data
      |> update_player2_name(name)
      ​|> update_rules(rules)
      ​|> reply_success(​:ok​)
    else
      :error​ -> {​:reply​, ​:error​, state_data}
​    end​
  ​end​

  def handle_call({:add_player, name}, _from, state) do
    Rules.add_player(state.fsm)
    |> add_player_reply(state, name)
  end

  def handle_call({:set_island_coordinates, player, island, coordinates}, _from, state) do
    Rules.move_island(state.fsm, player)
    |> set_island_coordinates_reply(player, island, coordinates, state)
  end

  def handle_call({:set_islands, player}, _from, state) do
    reply = Rules.set_islands(state.fsm, player)
    {:reply, reply, state}
  end

  def handle_call({:guess, player, coordinate}, _from, state) do
    opponent = opponent(state, player)
    board = Player.get_board(opponent)
    Rules.guess_coordinate(state.fsm, player)
    |> guess_reply(board, coordinate)
    |> forest_check(opponent, coordinate)
    |> win_check(opponent, state)
  end

  def handle_call(:demo, _from, state) do
    {:reply, state, state}
  end


  #helper functions
  defp update_player2_name(state_data, name), ​do​:
    put_in(state_data.player2.name, name)

  defp update_rules(state_data, rules), ​do​:
    %{state_data | ​rules:​ rules}

  ​defp reply_success(state_data, reply), ​do​:
    {​:reply​, reply, state_data}

  defp player_board(state_data, player), ​do​:
    Map.get(state_data, player).board
  defp update_board(state_data, player, board), ​do​:
    Map.update!(state_data, player, ​fn​ player -> %{player | ​board:​ board} ​end​)
  defp opponent(​:player1​), ​do​: ​:player2​
  ​​defp opponent(​:player2​), ​do​: ​:player1​
  defp update_guesses(state_data, player_key, hit_or_miss, coordinate) ​do​
    update_in(state_data[player_key].guesses, ​fn​ guesses ->
      Guesses.add(guesses, hit_or_miss, coordinate)
    ​end​)
  end​


  defp add_player_reply(:ok, state, name) do
    Player.set_name(state.player2, name)
    {:reply, :ok, state}
  end
  defp add_player_reply(reply, state, _name) do
    {:reply, reply, state}
  end

  defp set_island_coordinates_reply(:ok, player, island, coordinates, state) do
    Map.get(state, player)
    |> Player.set_island_coordinates(island, coordinates)
    {:reply, :ok, state}
  end
  defp set_island_coordinates_reply(reply, _player, _island, _coordinates, state) do
    {:reply, reply, state}
  end

  defp opponent(state, :player1) do
    state.player2
  end
  defp opponent(state, _player2) do
    state.player1
  end

  defp guess_reply(:ok, opponent_board, coordinate) do
    Player.guess_coordinate(opponent_board, coordinate)
  end
  defp guess_reply({:error, :action_out_of_sequence}, _opponent_board, _coordinate) do
    {:error, :action_out_of_sequence}
  end
  defp guess_reply(:error, _opponent_board, _coordinate) do
    :error
  end

  defp forest_check(:miss, _opponent, _coordinate) do
    {:miss, :none}
  end
  defp forest_check(:hit, opponent, coordinate) do
    island_key = Player.forested_island(opponent, coordinate)
    {:hit, island_key}
  end
  defp forest_check(:error, _opponent_board, _coordinate) do
    :error
  end


  defp win_check({hit_or_miss, :none}, _opponent, state) do
    {:reply, {hit_or_miss, :none, :no_win}, state}
  end
  defp win_check({:hit, island_key}, opponent, state) do
    win_status =
      case Player.win?(opponent) do
        true ->
          Rules.win(state.fsm)
          :win
          false -> :no_win
        end
        {:reply, {:hit, island_key, win_status}, state}
  end
  defp win_check(:error, _opponent, state) do
    {:reply, :error, state}
  end

end
