# Client snippets — Kkiapay widget integration

1) Obtenir le payload depuis le backend

Le client (web/mobile) appelle l'endpoint qui crée la session de paiement et retourne le payload (clé + montant + callback).

Exemple JS (fetch):

```javascript
async function createPayment(orderId, token) {
  const res = await fetch('/api/v1/payments/create', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token,
    },
    body: JSON.stringify({ order_id: orderId }),
  });
  return res.json();
}

// usage
createPayment('ORDER_UUID', 'USER_TOKEN').then(payload => {
  // inject widget
  const widget = document.createElement('kkiapay-widget');
  widget.setAttribute('amount', payload.widget.amount);
  widget.setAttribute('key', payload.widget.key);
  widget.setAttribute('callback', payload.widget.callback);
  document.body.appendChild(widget);
});
```

2) Exemple Android (pseudo)

Initialisation (Application):

```java
Kkiapay.init(getApplicationContext(), "42bce450b10e11f194f6bb659edc43c1",
    new SdkConfig.Builder()
        .setThemeColor(R.color.colorPrimary)
        .setImageResource(R.drawable.logo)
        .build());
```

Pour lancer le flow (après avoir demandé la session au serveur) :

```java
// payload from server contains amount and key
Kkiapay.open(this, payload.getKey(), payload.getAmount(), new Kkiapay.Callback() {
    @Override
    public void onCompleted(String transactionId) {
        // call backend /payments/verify to confirm
    }
    @Override
    public void onError(String error) { }
});
```

3) Notes

- Le client ne doit jamais décider du montant final : afficher ce que le backend renvoie.
- Après le paiement, le client redirige vers la callback et / ou interroge `/api/v1/payments/verify`.
