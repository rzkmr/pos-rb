# Single shop in production. Development/test bootstrap only — see CLAUDE.md.
current_fy = Shop.financial_year_for(Date.current)

shop = Shop.find_or_create_by!(name: "Sample Restaurant") do |s|
  s.address = "Thamel, Kathmandu"
  s.state_code = "3"
  s.prices_include_tax = true
  s.invoice_footer = "Thank you, visit again!"
  s.invoice_prefix = "INV"
  s.invoice_fy = current_fy
  s.invoice_sequence = 0
  s.pairing_pin = "9999"
end

Current.shop = shop

AdminUser.find_or_create_by!(shop: shop, username: "admin") do |u|
  u.password = "password123"
end

User.find_or_create_by!(shop: shop, name: "Cashier") do |u|
  u.role = "cashier"
  u.pin = "1111"
end

User.find_or_create_by!(shop: shop, name: "Waiter") do |u|
  u.role = "waiter"
  u.pin = "2222"
end

User.find_or_create_by!(shop: shop, name: "Kitchen") do |u|
  u.role = "kitchen"
  u.pin = "3333"
end

%w[T1 T2 T3 T4 Bar1 Bar2].each_with_index do |label, i|
  DiningTable.find_or_create_by!(shop: shop, label: label) do |t|
    t.seats = label.start_with?("Bar") ? 2 : 4
    t.position = i
  end
end

[
  { name: "Masala Dosa", category: "main", price_paise: 12_000 },
  { name: "Paneer Butter Masala", category: "main", price_paise: 25_000 },
  { name: "Veg Biryani", category: "main", price_paise: 22_000 },
  { name: "Butter Naan", category: "side", price_paise: 4_000 },
  { name: "Masala Chai", category: "beverage", price_paise: 3_000 },
  { name: "Sweet Lassi", category: "beverage", price_paise: 6_000 }
].each_with_index do |attrs, i|
  MenuItem.find_or_create_by!(shop: shop, name: attrs[:name]) do |m|
    m.category = attrs[:category]
    m.price_paise = attrs[:price_paise]
    m.hsn_sac = "996331"
    m.position = i
  end
end

puts "Seeded shop '#{shop.name}' — pairing PIN 9999, admin login admin/password123, staff PINs: cashier/1111, waiter/2222, kitchen/3333"
