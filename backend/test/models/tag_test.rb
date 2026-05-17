require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "name は必須" do
    tag = Tag.new(name: nil)
    refute tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  test "name は一意" do
    Tag.create!(name: "京都")
    dup = Tag.new(name: "京都")
    refute dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "name は 32 文字以内" do
    long = "あ" * 33
    tag = Tag.new(name: long)
    refute tag.valid?
    assert_includes tag.errors[:name], "is too long (maximum is 32 characters)"
  end

  # F-TAG-01 受け入れ条件: 「京都, 紅葉, 寺」入力で 3 件作成 / 重複は再利用
  test ".find_or_create_by_names は重複タグ名を再利用する" do
    Tag.create!(name: "京都")
    tags = Tag.find_or_create_by_names([ "京都", "紅葉", "寺" ])
    assert_equal 3, tags.size
    assert_equal 3, Tag.count, "既存タグは新規作成されない"
    assert_includes tags.map(&:name), "京都"
  end

  test ".find_or_create_by_names は前後空白を strip し空文字を除外する" do
    tags = Tag.find_or_create_by_names([ "  京都  ", "", "  ", "紅葉" ])
    assert_equal 2, tags.size
    assert_equal %w[京都 紅葉].sort, tags.map(&:name).sort
  end

  test ".find_or_create_by_names は同名重複入力をユニーク化する" do
    tags = Tag.find_or_create_by_names([ "京都", "京都", "紅葉" ])
    assert_equal 2, tags.size
  end
end
