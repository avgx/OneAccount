# OneAccount
Auth in VMS / cloud. Sign in / Refresh.

TODO нужно: Ошибки 401 + ключи вроде error.session.is.inactive, error.not.authenticated + ошибки при OTP в refresh / connect cloud.
+ Очистка сессии на сервере и потом проверка работоспособности

TODO нужно:
сформировать HTTPClient + RequestBuilder + Interceptor + Auth из AccountRecord в CurrentAccount при смене/установке аккаунта

TODO: Задать общие вещи через настройки: SSL, таймауты, логирование .

TODO: Задействовать PathStatistics из Get при формировании HTTP client.
