# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_03_04_111954) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "courses", force: :cascade do |t|
    t.bigint "event_id"
    t.string "name"
    t.integer "distance"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_courses_on_event_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "eventor_id"
    t.string "name"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["eventor_id"], name: "index_events_on_eventor_id", unique: true
  end

  create_table "races", force: :cascade do |t|
    t.integer "number"
    t.string "name"
    t.bigint "event_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_races_on_event_id"
  end

  create_table "results", force: :cascade do |t|
    t.bigint "course_id"
    t.integer "time"
    t.string "status"
    t.json "splits"
    t.string "gender"
    t.string "age_range"
    t.datetime "start_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "organisation"
    t.integer "age"
    t.integer "eventor_id"
    t.string "given_name"
    t.string "family_name"
    t.bigint "race_id"
    t.index ["age_range"], name: "index_results_on_age_range"
    t.index ["course_id"], name: "index_results_on_course_id"
    t.index ["gender"], name: "index_results_on_gender"
    t.index ["race_id"], name: "index_results_on_race_id"
  end

  add_foreign_key "courses", "events"
  add_foreign_key "races", "events"
  add_foreign_key "results", "courses"
  add_foreign_key "results", "races"
end
