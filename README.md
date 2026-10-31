# UKE Egzaminy (examinations8)

Zapisy na egzaminy na świadectwa operatora urządzeń radiowych (służba radioamatorska oraz morska i żeglugi
śródlądowej). Następca aplikacji `examinations` (Rails 5.2) – ta sama baza danych i te same adresy.

Rails 8.1, Ruby 4.0.7, PostgreSQL, Propshaft, importmap, Turbo, Stimulus, Bootstrap 5.3.8 (lokalnie), Devise +
SAML (WSO2), Pundit. Wygląd jak w confirmation8 (tryby jasny / ciemny / wysoki kontrast).

## Co robi aplikacja

- Logowanie kontem UKE (WSO2, SAML). Dane osobowe z konta wypełniają zgłoszenie.
- Kreator zgłoszenia: 1) służba, rodzaj i sesja (NETPAR), 2) dane podstawowe, 3) adres (TERYT albo zagraniczny),
  4) opłata (NETPAR, ulga do 18 lat) i załączniki, 5) podsumowanie i wysłanie do NETPAR.
- Lista zgłoszeń (także niedokończonych – „Dokończ” / „Usuń”), szczegóły z historią, anulowanie (do 14 dni przed
  egzaminem), zgłoszenie na egzamin poprawkowy, egzamin online (TestPortal).
- API dla NETPAR: `GET /api/v1/token` (Basic Auth), `PATCH /api/v1/proposals/:multi_app_identifier` – zmiana
  statusu, komentarza, sesji, odblokowanie testu. Każda zmiana statusu wysyła mail i trafia do historii zgłoszenia.
- Zadania z crona: przypomnienia 3 dni przed egzaminem, usuwanie niedokończonych zgłoszeń po 30 dniach.

## Uruchomienie lokalne

```bash
bundle install
# klucze credentials (poza git): config/credentials/development.key, test.key
bin/rails db:prepare
bin/rails s -p 3002
```

W trybie development na stronie głównej jest przycisk „Zaloguj (development – bez WSO2)” – loguje testowego
użytkownika. NETPAR (development) – `http://localhost:3001/api/v1`, TERYT – przez VPN.

Testy: `bin/rails test` (NETPAR i TERYT – WebMock), `bin/rubocop`, `bin/brakeman`.

## Konfiguracja

| Plik | Znaczenie |
|---|---|
| `config/examinations.yml` | limity czasu NETPAR/TERYT, adres TestPortal, Matomo (witryna 21), `test_for_all_unlocked` |
| `config/credentials/development.yml.enc`, `test.yml.enc` | lokalnie: `secret_key_base`, `database`, `host`, `netpar`, `teryt`, `saml`, `smtp`, `test_for_all_unlocked` (przeniesione z `secrets.yml` poprzedniej wersji) |
| `config/deploy/<serwer>/production.yml.enc` + `production.key` | serwery (`test2`, `prod`) – osobny klucz dla każdego serwera; poza gitem, na serwer przez `mina <serwer> credentials:upload` |
| zmienne środowiskowe | nadpisują credentials, np. `NETPAR_URL`, `DATABASE_HOST`, `MATOMO_ENABLED` – patrz `config/initializers/0_examinations.rb` |

Edycja credentials: lokalnie `bin/rails credentials:edit --environment development`, serwer –
`bin/rails encrypted:edit config/deploy/<serwer>/production.yml.enc --key config/deploy/<serwer>/production.key`,
na serwerze `bin/rails credentials:edit --environment production` (`config/credentials` w wydaniu to dowiązanie
do `shared/config/credentials`).
Bez kompletnych ustawień (NETPAR, TERYT, host, a na produkcji SAML i SMTP) aplikacja nie startuje.

## Baza danych

Ta sama struktura co `examinations`. Migracja `20251226104131_create_examinations_schema` ma numer ostatniej
migracji poprzedniej wersji – na istniejącej bazie się nie uruchamia, na pustej tworzy wszystko. Nowe migracje:

- `UpgradeActiveStorageForRails8` – `service_name`, tabela wariantów (wymagane od Rails 6.1),
- `SecureApiKeys` – hasło klucza API jako bcrypt, tokeny w `api_key_tokens` (skrót, ważność 1 h),
- `CreateProposalEvents` – historia zgłoszenia.

## Przełączenie z examinations – lista kontrolna

1. **Ten sam `secret_key_base`** co w poprzedniej wersji (credentials production) – inaczej przestaną działać
   linki do załączników, które NETPAR pokazuje urzędnikom (`*_blob_path`). Stare podpisy (Rails 5.2, SHA1)
   obsługuje `config/initializers/active_storage_legacy_links.rb`.
2. **Ten sam katalog załączników** (`storage/` – ActiveStorage, usługa `local`).
3. **Ta sama baza** (`database.name` w credentials) – `bin/rails db:migrate` doda tylko nowe tabele i kolumny.
4. **WSO2:** adres powrotu `/users/saml/auth` i `saml.issuer` bez zmian (`saml.callback_to` = dawne `idp_callback_to`).
5. **NETPAR:** dane klucza API (`egzaminy_api_user` / hasło w NETPAR) działają bez zmian – hasło przeliczone na bcrypt.
6. **Cron** (zamiast whenever):
   ```
   0 6 * * *   cd /ścieżka/current && RAILS_ENV=production bin/rails cronjobs:proposal_clean_unsaved
   0 10 * * *  cd /ścieżka/current && RAILS_ENV=production bin/rails cronjobs:proposal_send_reminders
   ```
7. **Po udanym przełączeniu:** migracja usuwająca jawne kolumny `api_keys.password` i `api_keys.access_token`
   (do tego czasu zostają na wypadek powrotu do poprzedniej wersji).

## Wymagania po stronie NETPAR

- `GET /divisions` z `enabled_in_examination=true` (rodzaje dla zapisów przez internet),
- `POST /proposals` bez duplikatów (ten sam `multi_app_identifier` → istniejące zgłoszenie, unikalny indeks),
- `PATCH /proposals/:id` – zmiana statusu przez API tylko na „anulowane”.

Wysyłanie zgłoszenia jest po naszej stronie odporne na powtórzenia i brak odpowiedzi
(`app/services/proposal_submission.rb`: blokada, „wysyłanie w toku”, przy ponowieniu najpierw `PATCH`).
