# osrs-translations
repository of oldschool runescape translations to other languages

## Updating translations

In order to update the translation files, you need to have access to the runelite-translator-api db and set up the `MONGODB_URI` env var.

Then, run the following command:

```bash
./update_translations.sh
```

This will update the available translations.
