require_relative 'viewbase'
require_relative '../observer_callback'

class GameView < ViewBase

  def initialize(model, controller)
    super
    @ui = SpriteUI.build {
      layout :horizontal_box
      TextLabel(:pause) {
        font Font20
        text "PAUSE"
        left 20
        top 15
        position :absolute
      }
      ContainerBox(:ships) {
        width 430
        margin [40, 20, 20]
        layout :horizontal_box
        justify_content :space_between
        4.times {
          ContainerBox {
            ContainerBox {
              layout :horizontal_box
              align_items :bottom
              width :full
              padding [8, 4]
              border width: 1, color: [127,127,127]
              height 30
              TextLabel(:lv) {
                width 0.4
                text "Lv.0"
                font Font16
              }
              TextButton(:gradeup) {
                font Font12
              }
            }
            ContainerBox {
              layout :flow
              margin [5, 0, 0, 0]
              border width: 1, color: [127,127,127]
              width 100
              height 100
              padding [10, 8]
              TextLabel(:stat) {
                font Font16
              }
            }
          }
        }
        add_event_handler :mouse_left_push, -> target {
          controller.on_ship_click(components.map {|component|
            component.find(:gradeup)
          }.find_index {|component|
            target == component and not component.disable?
          })
        }
      }
      ContainerBox(:warehouse) {
        margin [20, 20, 20, 30]
        padding [0, 10]
        height :full
        image Image.new(1,420).line(0,0,0,420,[127,127,127])
        TextLabel(:day) {
          text "1日目"
          font Font20
        }
        TextLabel(:time) {
          text "0:00"
          font Font20
        }
        TextLabel(:rate) {
          text "相場 10"
          font Font20
        }
        ContainerBox(:fishes) {
          width :full
          height 315
          add_event_handler :mouse_left_push, -> target {
            controller.on_fish_click(components.map {|component|
              component.find(:amount)
            }.find_index {|component|
              target == component
            })
          }
        }
        TextLabel(:money) {
          text "資金 600"
          font Font20
        }
      }
    }
    @ui.layout
    @ui.find(:ships).components.each_with_index do |ship, n|
      model.ships[n].add_observer(ObserverCallback.new {|event|
        event_type, value = *event.to_a.first
        case event_type
        when :levelup
          ship.find(:lv).text = "Lv.#{value.level.to_s}"
          if value.level > 0
            ship.find(:gradeup).text = "改造#{value.levelup_cost.to_s}"
            ship.find(:stat).text = "停泊中" if value.level == 1
          else
            ship.find(:gradeup).text = "購入#{value.levelup_cost.to_s}"
          end
        end
      })
      model.ships[n].notify_standby
    end
    time = @ui.find(:time)
    day = @ui.find(:day)
    rate = @ui.find(:rate)
    money = @ui.find(:money)
    ships = @ui.find(:ships).components
    fishes = @ui.find(:fishes).components
    model.add_observer(ObserverCallback.new {|event|
      event_type, value = *event.to_a.first
      case event_type
      when :new_day
        day.text = "#{@model.day.to_s}日目"
      when :new_hour
        time.text = "#{value.to_s}:00"
      when :new_rate
        rate.text = "相場 #{value.to_s}"
      when :new_money
        money.text = "資金 #{value.to_s}"
        sync_enum(ships, @model.ships).each {|ship, ship_model|
          enable_ship_upgrade(ship, ship_model)
        } unless model.infishing?
      when :start_fishing
        ships.each_with_index do |ship, n|
          disable_ship_upgrade(ship)
          if model.ships[n].level > 0
            ship.find(:stat).text = "作業中"
          end
        end
      when :start_business
        fishes.each {|fish| fish.find(:amount).enable }
      when :finish_business
        fishes.each {|fish| fish.find(:amount).disable }
      when :finish_fishing
        sync_enum(ships, @model.ships).each do |ship, ship_model|
          enable_ship_upgrade(ship, ship_model)
          if ship_model.level > 0
            ship.find(:stat).text = "停泊中"
          end
        end
      when :sell_all
        fishes.clear
      when :sell, :dispose
        fishes.delete_at(value)
      end
    })
    sync_enum(ships, @model.ships).each do |ship, ship_model|
      enable_ship_upgrade(ship, ship_model)
    end
    @mouse_event_dispatcher = SpriteUI::MouseEventDispatcher.new(@ui)
  end

  def enable_ship_upgrade(ship, ship_model)
    if @model.money >= ship_model.levelup_cost
      ship.find(:gradeup).color = nil
      ship.find(:gradeup).enable
    else
      ship.find(:gradeup).color = [255,255,63,0]
      ship.find(:gradeup).disable
    end
  end

  def sync_enum(array, other)
    array.lazy.zip(other)
  end

  def disable_ship_upgrade(ship)
    ship.find(:gradeup).color = nil
    ship.find(:gradeup).disable
  end

  def new_fish(fish_model)
    fish = SpriteUI.build {
      layout :horizontal_box;
      width :full
      TextButton(:amount) {
        width 88
        text "マグロ #{fish_model.amount.to_s}"
        font Font20
      }
      TextLabel(:gauge) {
        width 112
        text fish_model.limit_gauge
        font Font20
      }
    }.tap do |fish|
      fish_model.add_observer(ObserverCallback.new {|event|
        event_type, value = *event.to_a.first
        case event_type
        when :limit
          fish.find(:gauge).text = value
        end
      })
      fish.find(:amount).disable
    end
  end

  def update
    @mouse_event_dispatcher.update
    @ui.find(:pause).style_set(:visible, @model.pause?)
    fishes = @ui.find(:fishes)
    if @model.fishes.size > fishes.components.size
      @model.fishes.drop(fishes.components.size).each do |fish_model|
        fishes.add(new_fish(fish_model))
      end
    end
    @ui.layout
    @mouse_event_dispatcher.dispatch
  end

  def draw
    @ui.draw
  end

end
