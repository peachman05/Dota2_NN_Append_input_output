local sort_table = require("sort_table")

items = {
  {1004, "foo", 1},
  {8234, "bar", 2},
  {3188, "baz", 3},
  {8234, "auux", 4},
  {8234, "auux", 5},
}

sort_table.sort(items)

for key, value in pairs(items) do
  loop_print(value)
end
