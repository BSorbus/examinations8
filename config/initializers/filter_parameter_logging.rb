# Dane osobowe i dane logowania nie trafiają do logów (wnioski zawierają PESEL, adres, datę urodzenia itd.).
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :pesel, :passport, :name, :given_names, :family_name, :birth_date, :birth_place, :birth_city, :phone,
  :address, :city, :street, :c_address, :postal_code, :SAMLResponse, :SAMLRequest, :proposal
]
