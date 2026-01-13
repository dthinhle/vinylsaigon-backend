import { Application } from "@hotwired/stimulus"
import SidebarController from "./controllers/sidebar_controller"
import ConfirmController from "./controllers/confirm_controller"
import GalleryController from "./controllers/gallery_controller"
import ImagePreviewController from "./controllers/image_preview_controller"
import ProductsIndexController from "./controllers/products-index_controller"
import PromotionsIndexController from "./controllers/promotions_index_controller"
import CategoriesIndexController from "./controllers/categories_index_controller"
import CategoriesFormController from "./controllers/categories_form_controller"
import VariantAttributesController from "./controllers/variant_attributes_controller"
import ProductAttributesController from "./controllers/product_attributes_controller"
import ProductFormController from "./controllers/product_form_controller"
import BlogsIndexController from "./controllers/blogs-index_controller"
import BlogFormController from "./controllers/blog_form_controller"
import HeroBannersIndexController from "./controllers/hero-banners-index_controller"
import MenuBarSectionToggleController from "./controllers/menu_bar_section_toggle_controller"
import MenuItemSortController from "./controllers/menu_item_sort_controller"
import ToastController from "./controllers/toast_controller"
import MenuItemEditController from "./controllers/menu_item_edit_controller"
import MenuParentFormController from "./controllers/menu_parent_form_controller"
import MenuSubitemFormController from "./controllers/menu_subitem_form_controller"
import NestedFormController from "./controllers/nested_form_controller"
import MenuModalController from "./controllers/menu_modal_controller"
import MenuFormController from "./controllers/menu_form_controller"
import MenuSortableController from "./controllers/menu_sortable_controller"
import RedirectionMappingsIndexController from "./controllers/redirection-mappings-index_controller"
import TomSelectController from "./controllers/tom_select_controller"
import TomSelectRemoteController from "./controllers/tom_select_remote_controller"
import CustomersIndexController from "./controllers/customers-index_controller"
import AdminsFormController from "./controllers/admins-form_controller"
import RelatedCategoriesIndexController from "./controllers/related-categories-index_controller"
import RelatedCategoriesFormController from "./controllers/related-categories-form_controller"
import OrdersIndexController from "./controllers/orders-index_controller"
import PaymentTransactionsIndexController from "./controllers/payment-transactions-index_controller"
import BundlePromotionController from "./controllers/bundle_promotion_controller"
import TooltipController from "./controllers/tooltip_controller"
import LexicalEditorController from "./controllers/lexical_editor_controller"

import Clarity from '@microsoft/clarity';

import * as Turbo from "@hotwired/turbo"
window.Turbo = Turbo

window.Stimulus = Application.start()
window.Stimulus.register("nested-form", NestedFormController)
window.Stimulus.register("sidebar", SidebarController)
window.Stimulus.register("confirm", ConfirmController)
window.Stimulus.register("gallery", GalleryController)
window.Stimulus.register("image-preview", ImagePreviewController)
window.Stimulus.register("products-index", ProductsIndexController)
window.Stimulus.register("promotions-index", PromotionsIndexController)
window.Stimulus.register("categories-index", CategoriesIndexController)
window.Stimulus.register("categories-form", CategoriesFormController)
window.Stimulus.register("variant-attributes", VariantAttributesController)
window.Stimulus.register("product-form", ProductFormController)
window.Stimulus.register("product-attributes", ProductAttributesController)
window.Stimulus.register("hero-banners-index", HeroBannersIndexController)
window.Stimulus.register("blogs-index", BlogsIndexController)
window.Stimulus.register("blog-form", BlogFormController)
window.Stimulus.register("menu-bar-section-toggle", MenuBarSectionToggleController)
window.Stimulus.register("menu-item-sort", MenuItemSortController)
window.Stimulus.register("toast", ToastController)
window.Stimulus.register("menu-item-edit", MenuItemEditController)
window.Stimulus.register("menu-parent-form", MenuParentFormController)
window.Stimulus.register("menu-subitem-form", MenuSubitemFormController)
window.Stimulus.register("menu-modal", MenuModalController)
window.Stimulus.register("menu-form", MenuFormController)
window.Stimulus.register("menu-sortable", MenuSortableController)
window.Stimulus.register("redirection-mappings-index", RedirectionMappingsIndexController)
window.Stimulus.register("tom-select-remote", TomSelectRemoteController)
window.Stimulus.register("tom-select", TomSelectController)
window.Stimulus.register("customers-index", CustomersIndexController)
window.Stimulus.register("admins-form", AdminsFormController)
window.Stimulus.register("related-categories-index", RelatedCategoriesIndexController)
window.Stimulus.register("related-categories-form", RelatedCategoriesFormController)
window.Stimulus.register("orders-index", OrdersIndexController)
window.Stimulus.register("payment-transactions-index", PaymentTransactionsIndexController)
window.Stimulus.register("bundle-promotion", BundlePromotionController)
window.Stimulus.register("tooltip", TooltipController)
window.Stimulus.register("lexical-editor", LexicalEditorController)

// Microsoft Clarity Initialization
const cookies = document.cookie.split('; ').reduce((a, c) => {
  const [k, v] = c.split('=');
  return { ...a, [k]: decodeURIComponent(v) };
}, {});

if (cookies.clarity_project_id) {
  const projectId = cookies.clarity_project_id;
  Clarity.init(projectId);

  Clarity.setTag('app', '3kshop-admin');
  if (cookies.email && cookies.name)
    Clarity.identify(cookies.email, undefined, undefined, cookies.name);
}
