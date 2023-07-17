Rails.application.routes.draw do
  get '/results/:eventor_id', to: 'results#show', as: 'results'
  get '/results/:eventor_id/handicap', to: 'results#handicap_index'
  get '/results/:eventor_id/handicap_download', to: 'results#handicap_download', as: 'handicap_download'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
