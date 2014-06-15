defmodule KV.RouterTest do
  use ExUnit.Case, async: true

  @tag :distributed
  test "route requests accross nodes" do
    assert KV.Router.route("hello", Kernel, :node, []) ==
           :foo@jv
    assert KV.Router.route("world", Kernel, :node, []) ==
           :bar@jv
  end

  test "raises on unknown entries" do
    assert_raise RuntimeError, ~r/could not find entry/, fn ->
      KV.Router.route(<<0>>, Kernel, :node, [])
    end
  end
end
