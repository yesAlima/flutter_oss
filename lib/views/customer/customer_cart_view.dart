import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/customer/customer_cart_controller.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class CustomerCartView extends StatefulWidget {
  const CustomerCartView({Key? key}) : super(key: key);

  @override
  State<CustomerCartView> createState() => _CustomerCartViewState();
}

class _CustomerCartViewState extends State<CustomerCartView> {
  final CustomerCartController _controller = Get.find<CustomerCartController>();

  @override
  void initState() {
    super.initState();
    _controller.loadCart();
    _controller.loadAddresses();
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.category,
          size: 64,
          color: Colors.grey[400],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.error,
          size: 50,
        ),
      ),
    );
  }

  Widget _buildAddressSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: IconButton(
              icon: Obx(() => Icon(
                _controller.isAddressExpanded.value ? Icons.expand_less : Icons.expand_more,
              )),
              onPressed: _controller.toggleAddressExpanded,
            ),
          ),
          Obx(() => _controller.isAddressExpanded.value ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _controller.addresses.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No addresses found. Please add an address to place your order.'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Get.toNamed(AppRoutes.customerAddressForm);
                          _controller.loadAddresses();
                        },
                        icon: const Icon(Icons.add_location),
                        label: const Text('Add Address'),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Select a delivery address:'),
                        TextButton.icon(
                          onPressed: () async {
                            await Get.toNamed(AppRoutes.customerAddressForm);
                            _controller.loadAddresses();
                          },
                          icon: const Icon(Icons.add_location),
                          label: const Text('Add New'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: _controller.addresses.map((address) => RadioListTile<AddressModel>(
                        value: address,
                        groupValue: _controller.selectedAddress.value,
                        onChanged: (value) {
                          if (value != null) {
                            _controller.updateCartAddress(value);
                          }
                        },
                        title: Text('Block ${address.block}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (address.road != null) Text('Road ${address.road}'),
                            Text('Building ${address.building}'),
                          ],
                        ),
                      )).toList(),
                    ),
                  ],
                ),
          ) : const SizedBox.shrink()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.cart.value == null || _controller.cart.value!.orderlines.isEmpty) {
          return const Center(
            child: Text('Your cart is empty'),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildAddressSelector(),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _controller.cart.value!.orderlines.length,
                    itemBuilder: (context, index) {
                      final line = _controller.cart.value!.orderlines[index];
                      final product = _controller.products[line.id];
                      
                      if (product == null) return const SizedBox.shrink();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _buildProductImage(product.imageUrl),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${product.price.toStringAsFixed(3)} BD',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          onPressed: line.quantity > 1
                                              ? () => _controller.updateQuantity(
                                                    line.id,
                                                    line.quantity - 1,
                                                  )
                                              : null,
                                        ),
                                        Text(
                                          '${line.quantity}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: line.quantity < product.stock
                                              ? () => _controller.updateQuantity(
                                                    line.id,
                                                    line.quantity + 1,
                                                  )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _controller.updateQuantity(line.id, 0),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Obx(() => Text(
                          '${_controller.getCartTotal().toStringAsFixed(3)} BD',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _controller.selectedAddress.value != null ? _controller.placeOrder : null,
                        child: const Text('Place Order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
} 