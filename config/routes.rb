Mercury::Engine.routes.draw do
  get '/editor(/*requested_uri)' => "mercury#edit", :as => :mercury_editor

  scope '/mercury' do
    get ':type/:resource' => "mercury#resource"
    post 'snippets/:name/options' => "mercury#snippet_options"
    post 'snippets/:name/preview' => "mercury#snippet_preview"
  end
end
