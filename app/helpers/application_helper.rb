module ApplicationHelper
  include Pagy::NumericHelpers
  include Pagy::Linkable

  def nav_link(label, path, active: false)
    classes = active ? "flex items-center gap-3 px-4 py-2 rounded-lg text-sm font-medium bg-slate-800 text-white" : "flex items-center gap-3 px-4 py-2 rounded-lg text-sm font-medium text-slate-400 hover:bg-slate-800 hover:text-white transition-colors"
    link_to label, path, class: classes
  end

  def status_badge(status)
    return tag.span "—", class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium text-gray-600 bg-gray-50" unless status

    classes = case status
    when 200..299 then "text-emerald-600 bg-emerald-50"
    when 300..399 then "text-blue-600 bg-blue-50"
    when 400..499 then "text-amber-600 bg-amber-50"
    when 500..599 then "text-red-600 bg-red-50"
    else "text-gray-600 bg-gray-50"
    end

    tag.span status, class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{classes}"
  end

  def stat_card(label, value, accent_class)
    tag.div class: "bg-slate-900 rounded-xl border border-slate-800 p-6" do
      tag.div(label, class: "text-sm text-slate-500") +
      tag.div(value, class: "text-3xl font-bold #{accent_class} mt-2")
    end
  end

  def detail_row(label, value)
    return unless value.present?

    tag.div(class: "space-y-1") do
      tag.span(label, class: "text-xs text-slate-500 uppercase tracking-wide") +
      tag.div(value, class: "text-sm text-slate-200 break-all")
    end
  end
end
