describe 'role methods' do
  it 'identifies c_support role' do
    user = build(:user, role: 'c_support')
    expect(user.c_support?).to be true
    expect(user.staff?).to be true
  end

  it 'identifies manager role' do
    user = build(:user, role: 'manager')
    expect(user.manager?).to be true
    expect(user.staff?).to be true
  end

  it 'includes new roles in staff?' do
    c_support = build(:user, role: 'c_support')
    manager = build(:user, role: 'manager')
    customer = build(:user, role: 'customer')

    expect(c_support.staff?).to be true
    expect(manager.staff?).to be true
    expect(customer.staff?).to be false
  end
end
