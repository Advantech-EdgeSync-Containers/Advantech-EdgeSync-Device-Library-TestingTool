# 在函式內使用 echo，在函式呼叫端使用 command substitution，模擬回傳字串的行為

my_func() {
    local result="Hello from function"
    echo "$result"
}

output=$(my_func)
echo "Function returned: $output"