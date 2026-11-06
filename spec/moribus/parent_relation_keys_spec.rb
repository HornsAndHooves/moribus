require "spec_helper"

describe "Moribus parent relation keys" do
  it "resolves an association declared after acts_as_tracked" do
    model = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      acts_as_tracked by: :owner

      belongs_to :owner, class_name: "User", foreign_key: :owner_id
    end

    expect(model.parent_relation_keys).to eq(["owner_id"])
  end

  it "resolves an association declared before acts_as_tracked" do
    model = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      belongs_to :owner, class_name: "User", foreign_key: :owner_id

      acts_as_tracked by: :owner
    end

    expect(model.parent_relation_keys).to eq(["owner_id"])
  end

  it "does not cache keys before an association is declared" do
    model = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      acts_as_tracked by: :owner
    end

    expect(model.parent_relation_keys).to eq([])

    model.belongs_to :owner, class_name: "User", foreign_key: :owner_id

    expect(model.parent_relation_keys).to eq(["owner_id"])
  end

  it "returns no keys when by is omitted" do
    model = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      belongs_to :owner, class_name: "User", foreign_key: :owner_id

      acts_as_tracked
    end

    expect(model.parent_relation_keys).to eq([])
  end

  it "resolves multiple parent associations" do
    model = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      acts_as_tracked by: [:owner, :category]

      belongs_to :owner,    class_name: "User",     foreign_key: :owner_id
      belongs_to :category, class_name: "Category", foreign_key: :category_id
    end

    expect(model.parent_relation_keys).to contain_exactly("owner_id", "category_id")
  end

  it "inherits parent configuration without changing it when a subclass overrides by" do
    parent = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      acts_as_tracked by: :owner

      belongs_to :owner,    class_name: "User",     foreign_key: :owner_id
      belongs_to :category, class_name: "Category", foreign_key: :category_id
    end
    child = Class.new(parent)

    expect(child.parent_relation_keys).to eq(["owner_id"])

    child.class_eval { acts_as_tracked by: :category }

    expect(child.parent_relation_keys).to  eq(["category_id"])
    expect(parent.parent_relation_keys).to eq(["owner_id"])
  end
end
