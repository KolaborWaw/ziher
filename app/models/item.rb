# encoding: utf-8
# TODO: move strings to I18n
class Item < ApplicationRecord
  audited

  belongs_to :entry
  belongs_to :category

  has_many :item_grants, dependent: :destroy
  has_many :grants, through: :item_grants

  accepts_nested_attributes_for :item_grants

  before_validation :remove_nil_amount_grants
  before_validation :remove_zero_amount_grants
  before_validation :set_same_values_for_one_percent_category

  validate :cannot_have_amount_one_percent_greater_than_amount
  validate :cannot_have_amount_one_percent_if_amount_is_nil

  validate :cannot_have_grant_amounts_if_self_amount_is_nil

  validate :cannot_have_bigger_grants_and_one_percent_amounts_sum_than_item_amount

  validate :grants_and_one_percent_amount_should_have_same_sign_as_self_amount

  def amount=(val)
    write_attribute :amount, val.to_s.gsub(/[,\s+]/, ',' => '.', '\s+' => '')
  end

  def amount_one_percent=(val)
    write_attribute :amount_one_percent, val.to_s.gsub(/[,\s+]/, ',' => '.', '\s+' => '')
  end

  def set_same_values_for_one_percent_category
    if self.category.is_one_percent
      self.amount_one_percent = self.amount
    end
  end

  def remove_nil_amount_grants
    # so you can just delete from the form
    self.item_grants.each do |ig|
     ig.destroy if ig.amount == nil
    end
  end

  def remove_zero_amount_grants
    # so you can just set to zero in the form
    self.item_grants.each do |ig|
     ig.destroy if ig.amount == 0
    end
  end

  def cannot_have_amount_one_percent_greater_than_amount
    if self.amount != nil && self.amount_one_percent != nil
      if self.amount_one_percent.abs > self.amount.abs && !category.is_one_percent
        errors[:items] << " - value for 1% (#{self.amount_one_percent}) must be less than main value (#{self.amount})"
      end
    end
  end

  def cannot_have_amount_one_percent_if_amount_is_nil
    if self.amount == nil && self.amount_one_percent != nil && self.amount_one_percent != 0 then
      errors[:items] << " - provided value for 1% (#{self.amount_one_percent}) without providing main value"
    end
  end

  def cannot_have_grant_amounts_if_self_amount_is_nil
    grants_amounts = self.item_grants.map(&:amount).map(&:to_i)

    if self.amount == nil && grants_amounts.count > 0 && grants_amounts.sum != 0 then
      errors[:items] << " - provided grant amounts (in sum #{grants_amounts.sum}) without providing main value"
    end
  end

  def cannot_have_bigger_grants_and_one_percent_amounts_sum_than_item_amount
    grants_sum = self.item_grants.map(&:amount).sum(&:to_i) + self.amount_one_percent.to_i
    if grants_sum.abs > self.amount.to_i.abs

      errors[:items] << "Sum of grants (" + grants_sum.to_s + ") must fit within item value (" + self.amount.to_s + ")"
    end
  end

  def grants_and_one_percent_amount_should_have_same_sign_as_self_amount
    error = false

    grants_amounts = self.item_grants.map(&:amount).map(&:to_i)
    return if self.amount == nil

    if self.amount > 0
      error = true if self.amount_one_percent != nil && self.amount_one_percent < 0

      grants_amounts.each do |amount|
        error = true if amount < 0
      end

      if error
        errors[:items] << "If item value is greater than 0 then grant amounts must also be greater than 0"
      end

    elsif self.amount < 0
      error = true if self.amount_one_percent != nil && self.amount_one_percent > 0

      grants_amounts.each do |amount|
        error = true if amount > 0
      end

      if error
        errors[:items] << "If item value is less than 0 then grant amounts must also be less than 0"
      end
    end
  end

  def Item.get_by_category_and_grant(category_id, grant_id)
    Item.includes(:grants).joins(:item_grants).where(category_id: category_id, item_grants: {grant_id: grant_id})
  end
end
