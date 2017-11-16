
local sort_table = {} 
sort_table.__index =table

function compare(a,b)
  
  for i = 1,#a do
    print(i)
    print(a[i].." "..b[i] )
    if a[i] ~= b[i] or i == #a then    
      return a[i] < b[i]
    end    

  end
end

function loop_print( tb )
  for key , value in pairs(tb) do
    print(key.." "..value)
  end
end

function sort_table.sort(input)
    table.sort(input, compare)
end

-- sort_table.sort()
return sort_table