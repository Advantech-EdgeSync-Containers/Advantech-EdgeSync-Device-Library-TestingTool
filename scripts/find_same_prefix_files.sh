# ls -al /usr/lib/libSUSI*

prefix="/usr/lib/libSUSI-"
file_list=()

for file in ${prefix}*; do
    # 檢查是否為檔案或 link
    if [[ -e "$file" ]]; then

        # 是 symbolic link，取得 link 的目標
        if [[ -L "$file" ]]; then
            target=$(readlink "$file")
            echo "檔案名稱：$file → 是 symbolic link, 指向 : $target"
        else
            echo "檔案名稱：$file → 不是 symbolic link"

            file_list+=($file)
        fi
    fi
done

echo "${file_list[@]}"  # Echo list
echo ${#file_list[@]}   # Echo list length

if [ ${#file_list[@]} -eq 0 ]; then
  echo "SUSI not found"
fi