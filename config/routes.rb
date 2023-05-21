Rails.application.routes.draw do
  get '/results/:eventor_id', to: 'results#show', as: 'results'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
