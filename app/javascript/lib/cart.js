// Pure cart operations — a cart is a Map<menuItemId, {menuItemId, name,
// unitPricePaisa, quantity}>. Every function returns a NEW Map; none
// mutate the one passed in. Shared between the online takeaway checkout
// screen and the offline shell so there's exactly one implementation of
// "what does adding an item actually do," not two that can drift.
export function addItem(cart, { menuItemId, name, unitPricePaisa }) {
  const existing = cart.get(menuItemId)
  const next = new Map(cart)
  next.set(menuItemId, {
    menuItemId, name, unitPricePaisa,
    quantity: (existing?.quantity ?? 0) + 1
  })
  return next
}

export function updateQuantity(cart, menuItemId, delta) {
  const item = cart.get(menuItemId)
  if (!item) return cart

  const next = new Map(cart)
  const quantity = item.quantity + delta
  if (quantity <= 0) {
    next.delete(menuItemId)
  } else {
    next.set(menuItemId, { ...item, quantity })
  }
  return next
}

export function removeItem(cart, menuItemId) {
  if (!cart.has(menuItemId)) return cart
  const next = new Map(cart)
  next.delete(menuItemId)
  return next
}

export function clear() {
  return new Map()
}

export function itemCount(cart) {
  return Array.from(cart.values()).reduce((sum, item) => sum + item.quantity, 0)
}

export function grossPaisa(cart) {
  return Array.from(cart.values()).reduce((sum, item) => sum + item.quantity * Number(item.unitPricePaisa), 0)
}
